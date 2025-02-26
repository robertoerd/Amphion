# frozen_string_literal: true

#
# Copyright (C) 2025 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

class CoursePacing::BulkStudentEnrollmentPacesApiController < CoursePacing::PacesApiController
  before_action :require_feature_flag
  before_action :require_context
  before_action :ensure_pacing_enabled
  before_action :authorize_action

  include GranularPermissionEnforcement

  def student_bulk_pace_edit_view
    course_id = @context.id

    per_page, offset = pagination_params

    enrolled_students = fetch_filtered_enrolled_students(course_id)
    active_sections = CourseSection.where(course_id: course_id, workflow_state: "active")

    enrolled_students = apply_sorting(enrolled_students)

    total_students, paginated_students = paginate_students(enrolled_students, offset, per_page)

    students_status = students_on_pace_status(course_id, paginated_students).index_by { |s| s[:student_id] }

    if params[:filter_pace_status].present?
      paginated_students.select! do |enrollment|
        pace_status = students_status[enrollment.user.id]&.dig(:on_pace) ? "on-pace" : "off-pace"
        pace_status == params[:filter_pace_status]
      end
    end

    render json: {
      students: build_students_data(paginated_students, enrolled_students, students_status),
      pages: (total_students.to_f / per_page).ceil,
      sections: active_sections.map { |section| build_section_json(section) }
    }
  end

  private

  def pagination_params
    page = (params[:page].to_i > 0) ? params[:page].to_i : 1
    per_page = (params[:per_page].to_i > 0) ? params[:per_page].to_i : 10
    offset = (page - 1) * per_page
    [per_page, offset]
  end

  def fetch_filtered_enrolled_students(course_id)
    students = StudentEnrollment.active
                                .where(course_id: course_id)
                                .preload(:user)
                                .preload(:course_section)

    if params[:filter_section].present?
      students = students.where(course_section_id: params[:filter_section])
    end

    if params[:search_term].present?
      students = students.joins(:user).where("users.name ILIKE ?", "%#{params[:search_term]}%")
    end

    individual_paced_user_ids = CoursePace
                                .where(course_id: course_id, workflow_state: "active")
                                .where.not(user_id: nil)
                                .pluck(:user_id)

    students = students.where.not(user_id: individual_paced_user_ids) if individual_paced_user_ids.any?

    students
  end

  def apply_sorting(enrolled_students)
    if params[:sort].present?
      order_direction = (params[:order] == "desc") ? "DESC" : "ASC"
      enrolled_students.joins(:user).order("users.name #{order_direction}")
    else
      enrolled_students.order(created_at: :desc)
    end
  end

  def paginate_students(enrolled_students, offset, per_page)
    total_students = enrolled_students.select(:user_id).distinct.count
    unique_students = enrolled_students.group_by(&:user).values.map(&:first)
    paginated_students = unique_students.drop(offset).first(per_page)
    [total_students, paginated_students]
  end

  def build_students_data(paginated_students, enrolled_students, students_status)
    # Pre-fetch all sections for the paginated students in a single query
    student_ids = paginated_students.map(&:user_id)
    sections_by_student = enrolled_students
                          .where(user_id: student_ids)
                          .preload(:course_section)
                          .group_by(&:user_id)

    paginated_students.map do |enrollment|
      student = enrollment.user
      student_sections = sections_by_student[student.id]&.filter_map(&:course_section)&.uniq || []

      {
        id: student.id.to_s,
        name: student.name,
        paceStatus: students_status[student.id]&.dig(:on_pace) ? "on-pace" : "off-pace",
        enrollmentId: enrollment.id.to_s,
        enrollmentDate: enrollment.created_at.iso8601,
        sections: student_sections.map { |section| build_section_json(section) }
      }
    end
  end

  def build_section_json(section)
    {
      id: section.id.to_s,
      course_id: section.course_id.to_s,
      name: section.name
    }
  end

  def students_on_pace_status(course_id, paginated_students)
    students = paginated_students.map(&:user)

    assignments = Assignment
                  .joins(
                    "LEFT JOIN public.assignment_overrides ON assignments.id = public.assignment_overrides.assignment_id
                      LEFT JOIN public.assignment_override_students ON public.assignment_overrides.id = public.assignment_override_students.assignment_override_id"
                  )
                  .where("assignments.context_id = ? AND assignments.context_type = ? AND assignments.workflow_state = 'published'", course_id, "Course")
                  .where.not(assignments: { submission_types: "none" })
                  .where("public.assignment_overrides.workflow_state = 'active' OR public.assignment_overrides.id IS NULL")
                  .where("public.assignment_override_students.workflow_state = 'active' OR public.assignment_override_students.id IS NULL")
                  .select("assignments.id, assignments.title, assignments.workflow_state,
                            public.assignment_overrides.due_at, public.assignment_override_students.user_id")

    # Get unique assignment IDs to avoid duplicates in the IN clause
    assignment_ids = assignments.map(&:id).uniq

    submissions = Submission
                  .where(assignment_id: assignment_ids)
                  .where.not(workflow_state: ["unsubmitted", "deleted"])
                  .select("DISTINCT ON (user_id, assignment_id) *")
                  .order("user_id, assignment_id, created_at DESC")
                  .group_by { |s| [s.user_id, s.assignment_id] }

    students.map do |student|
      missing_submission = assignments.any? do |assignment|
        next unless assignment.user_id.nil? || assignment.user_id == student.id

        past_due = assignment.due_at.present? && assignment.due_at < Time.current
        has_submission = submissions.key?([student.id, assignment.id])
        no_submission = !has_submission
        past_due && no_submission
      end

      { student_id: student.id, on_pace: !missing_submission }
    end
  end

  def authorize_action
    enforce_granular_permissions(
      @course,
      overrides: [:manage_content],
      actions: {
        student_bulk_pace_edit_view: RoleOverride::GRANULAR_MANAGE_COURSE_CONTENT_PERMISSIONS
      }
    )
  end

  def ensure_pacing_enabled
    not_found unless @context.enable_course_paces
  end

  attr_reader :course

  def context
    @student_enrollment
  end

  def load_contexts
    @course = api_find(Course.active, params[:course_id])
    @draft_feature_flag_enabled = @course.root_account.feature_enabled?(:course_pace_draft_state)
    if params[:student_enrollment_id]
      @student_enrollment = @course.student_enrollments.find(params[:student_enrollment_id])
    end
  end
end
