# frozen_string_literal: true

#
# Copyright (C) 2013 - present Instructure, Inc.
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
#

module AccountReports
  module ImprovedOutcomeReports
    class OutcomeResultsReport < BaseOutcomeReport
      include CanvasOutcomesHelper
      include OutcomesServiceAuthoritativeResultsHelper

      HEADERS = [
        "student name",
        "student id",
        "student sis id",
        "assessment title",
        "assessment id",
        "assessment type",
        "submission date",
        "submission score",
        "learning outcome name",
        "learning outcome id",
        "attempt",
        "outcome score",
        "assessment question",
        "assessment question id",
        "course name",
        "course id",
        "course sis id",
        "section name",
        "section id",
        "section sis id",
        "assignment url",
        "learning outcome friendly name",
        "learning outcome points possible",
        "learning outcome mastery score",
        "learning outcome mastered",
        "learning outcome rating",
        "learning outcome rating points",
        "learning outcome group title",
        "learning outcome group id",
        "account id",
        "account name",
        "enrollment state"
      ].freeze

      # returns rows for each assessed outcome result (or question result)
      def generate
        # Add text to the report description if user supplied ordering parameter
        add_outcome_order_text
        config_options = { new_quizzes_scope: outcomes_new_quiz_scope }
        write_outcomes_report(HEADERS, outcome_results_scope, config_options)
      end

      private

      def add_outcome_order_text
        order = determine_order_key
        if order
          add_extra_text(I18n.t("account_reports.outcomes.order", "Order: %{order}", order:))
        end
      end

      def join_course_sub_account_scope(account, scope, table = "courses")
        if account == account.root_account
          scope
        else
          scope.joins(<<~SQL.squish)
            join #{CourseAccountAssociation.quoted_table_name} caa
              ON caa.account_id = #{account.id}
              AND caa.course_id = #{table}.id
              AND caa.course_section_id IS NULL
          SQL
        end
      end

      # Only load student, submission, and course section information for students
      # that have results. This prevents us from loading all this information just to
      # later discard it because there are no results from outcome service.
      def decorate_result(account, course, assignment, outcome, os_result)
        students = User.select(<<~SQL.squish)
          distinct on (users.id, p.id, s.id)
          users.sortable_name                         AS "student name",
          users.uuid                                  AS "student uuid",
          p.user_id                                   AS "student id",
          p.sis_user_id                               AS "student sis id",
          subs.submitted_at                           AS "submission date",
          subs.score                                  AS "submission score",
          'quiz'                                      AS "assessment type",
          s.name                                      AS "section name",
          s.id                                        AS "section id",
          s.sis_source_id                             AS "section sis id",
          e.workflow_state                            AS "enrollment state"
        SQL
                       .joins(<<~SQL.squish)
                         INNER JOIN #{Enrollment.quoted_table_name} e ON e.type = 'StudentEnrollment' AND e.root_account_id = #{course.root_account.id}
                           AND e.course_id = #{course.id} AND e.user_id = users.id #{"AND e.workflow_state <> 'deleted'" unless @include_deleted}
                         INNER JOIN #{Pseudonym.quoted_table_name} p ON p.user_id = users.id #{"AND p.workflow_state<>'deleted'" unless @include_deleted}
                         INNER JOIN #{CourseSection.quoted_table_name} s ON e.course_section_id = s.id
                         LEFT OUTER JOIN #{Submission.quoted_table_name} subs ON subs.assignment_id = #{os_result[:associated_asset_id].to_i}
                           AND subs.user_id = users.id AND subs.workflow_state <> 'deleted' AND subs.workflow_state <> 'unsubmitted'
                       SQL
                       .where(uuid: os_result[:user_uuid])

        return [] if students.empty?

        results = []
        students.each do |s|
          student = s.attributes
          student["assignment id"] = assignment["assignment id"]
          student["assessment title"] = assignment["assessment title"]
          student["assessment id"] = assignment["assessment id"]
          student["learning outcome name"] = outcome["learning outcome name"]
          student["learning outcome id"] = outcome["learning outcome id"]
          student["learning outcome friendly name"] = outcome["learning outcome friendly name"]
          student["learning outcome data"] = outcome["learning outcome data"]
          student["learning outcome group title"] = outcome["learning outcome group title"]
          student["learning outcome group id"] = outcome["learning outcome group id"]
          student["course name"] = course.name
          student["course id"] = course.id
          student["course sis id"] = course.sis_source_id
          student["account id"] = account["account id"]
          student["account name"] = account["account name"]

          results.concat(combine_result(student, os_result))
        end
        results
      end

      def combine_result(student, authoritative_result)
        learning_outcome_result = convert_to_learning_outcome_result(authoritative_result)
        base_student = student.merge(
          {
            "learning outcome mastered" => learning_outcome_result.mastery,
            "learning outcome points hidden" => nil, # TODO: hide_points is a column on AR, but not populated
            "total percent outcome score" => learning_outcome_result.percent,

            # If the outcome is aligned with individual questions, these values will be overwritten by
            # data on the attempt meta data
            "learning outcome points possible" => learning_outcome_result.possible,
            "outcome score" => learning_outcome_result.score,

            # This field is used to disambiguate results returned from OS. You can see
            # where it is used above in outcomes_new_quiz_scope
            "result submitted at" => authoritative_result[:submitted_at],

            # TODO: OUT-5460 We should be getting this off the attempt (attempt number)
            # We only care about the most recent attempt. The attempt column is equal to number of attempts
            "attempt" => authoritative_result[:attempts]&.length
          }
        )

        # If there are no attempts, we still include the result in the report. This is likely older submission from before
        # we were capturing attempt info. If there are multiple attempts, we only include the most recent one in the
        # report. To determine the most recent attempt, we use the submitted_At attribute, but historically, that field
        # was not populated in outcome service. We will use it if we have it, but if it is missing, we will fallback
        # to created_at. Using the created_at is technically not correct, but is the better than nothing. We should be
        # using the attempt number though because that is 100% accurate.
        # TODO: OUT-5460 We should use the attempt number if present to determine what attempt to use
        results = []
        attempt = authoritative_result[:attempts]&.max_by { |a| a[:submitted_at] || a[:created_at] }

        if attempt.nil? || attempt[:metadata].nil?
          # If we do not have an attempt but we do have a result, ensure that attempt number is at least 1
          base_student["attempt"] = 1 unless base_student["attempt"] > 0
          results.push(base_student)
        else
          meta_data = attempt[:metadata]
          question_metadata = meta_data[:question_metadata]

          # Assessment title and id are populated from the canvas Assignment record. In the future, we can get this from
          # the quiz_metadata on the attempt. If/When we do this, we will need to change the metadata format of the quiz
          # to always include quiz id and title. See comment on https://instructure.atlassian.net/browse/OUT-5292
          if question_metadata.blank?
            results.push(base_student)
          else
            question_metadata.each do |question|
              question_row = base_student.clone
              learning_outcome_question_result = metadata_to_outcome_question_result(
                learning_outcome_result,
                question,
                question_row["attempt"]
              )

              question_row["assessment question id"] = question[:quiz_item_id]
              question_row["assessment question"] = question[:quiz_item_title]
              question_row["learning outcome points possible"] = learning_outcome_question_result.possible
              question_row["outcome score"] = learning_outcome_question_result.score
              question_row["learning outcome mastered"] = learning_outcome_question_result.mastery

              # We do not want to set the "total percent outcome score" to learning_outcome_question_result.percent
              # because that is the percentage the student got on the individual question. "total percent outcome score"
              # was set based of learning_outcome_result.percent (see above), which takes into account all the questions
              # aligned with this same outcome. "total percent outcome score" is what is used to determine
              # "learning outcome rating" and "learning outcome rating points". This is weird because
              # "learning outcome mastered" is set based off the learning_outcome_question_result.mastery, so
              # it's possible for "learning outcome mastered" to be 0, but "learning outcome mastered" to
              # be "Exceeds Mastery". The reason for this behavior is to mimic what is in the existing report. In the
              # future we will reevaluate what columns are in this report.
              results.push(question_row)
            end
          end
        end
        results
      end

      def outcomes_new_quiz_scope
        return [] unless account.feature_enabled?(:outcome_service_results_to_canvas)

        nq_assignments = account.learning_outcome_links.active
                                .select(<<~SQL.squish)
                                  distinct on (learning_outcomes.id, c.id, a.id)
                                  learning_outcomes.short_description         AS "learning outcome name",
                                  learning_outcomes.id                        AS "learning outcome id",
                                  learning_outcomes.display_name              AS "learning outcome friendly name",
                                  learning_outcomes.data                      AS "learning outcome data",
                                  g.title                                     AS "learning outcome group title",
                                  g.id                                        AS "learning outcome group id",
                                  c.name                                      AS "course name",
                                  c.id                                        AS "course id",
                                  c.sis_source_id                             AS "course sis id",
                                  a.id                                        AS "assignment id",
                                  a.title                                     AS "assessment title",
                                  a.id                                        AS "assessment id",
                                  acct.id                                     AS "account id",
                                  acct.name                                   AS "account name"
                                SQL
                                .joins(<<~SQL.squish)
                                  INNER JOIN #{LearningOutcome.quoted_table_name} ON learning_outcomes.id = content_tags.content_id
                                    AND content_tags.content_type = 'LearningOutcome'
                                  INNER JOIN #{LearningOutcomeGroup.quoted_table_name} g ON g.id = content_tags.associated_asset_id
                                    AND content_tags.associated_asset_type = 'LearningOutcomeGroup'
                                  INNER JOIN #{ContentTag.quoted_table_name} cct ON cct.content_id = content_tags.content_id AND cct.context_type = 'Course'
                                  INNER JOIN #{Course.quoted_table_name} c ON cct.context_id = c.id
                                  INNER JOIN #{Account.quoted_table_name} acct ON acct.id = c.account_id
                                  INNER JOIN #{Assignment.quoted_table_name} a ON (a.context_id = c.id AND a.context_type = 'Course'
                                  AND a.submission_types = 'external_tool' AND a.workflow_state <> 'deleted')
                                SQL

        unless @include_deleted
          nq_assignments = nq_assignments.where("c.workflow_state IN ('available', 'completed')")
        end

        nq_assignments = join_course_sub_account_scope(account, nq_assignments, "c")
        nq_assignments = add_term_scope(nq_assignments, "c")
        return [] if nq_assignments.empty?

        # We need to call the outcomes service once per course to get the authoritative results for each student. This
        # takes the results from the query above and transform it to a hash of course => (assignments, outcomes)
        # This hash will be used to call outcome service and the results from outcome service will be joined with the
        # results from the query.
        #
        # The other hashes are used to decorate the results once fetched from OS
        courses = {}
        accounts = {}
        assignments = {}
        outcomes = {}
        nq_assignments.each do |s|
          c_id = s["course id"]
          if courses.key?(c_id)
            course_map = courses[c_id]
            course_map[:assignment_ids].add(s["assignment id"])
            course_map[:outcome_ids].add(s["learning outcome id"])
          else
            courses[c_id] = { course_id: c_id, assignment_ids: Set[s["assignment id"]], outcome_ids: Set[s["learning outcome id"]] }
          end
          accounts[s["account id"]] = s
          assignments[s["assignment id"].to_s] = s
          outcomes[s["learning outcome id"].to_s] = s
        end

        student_results = {}
        courses.each_value do |c|
          # There is no need to check if the feature flag :outcome_service_results_to_canvas is enabled for the
          # course because get_lmgb_results will return nil if it is not enabled
          course = Course.find(c[:course_id])
          account = accounts[course.account_id]

          assignment_ids = c[:assignment_ids].to_a.join(",")
          outcome_ids = c[:outcome_ids].to_a.join(",")
          os_results = get_lmgb_results(course, assignment_ids, "canvas.assignment.quizzes", outcome_ids)
          next if os_results.nil?

          os_results.each do |authoritative_result|
            composite_key = "#{c[:course_id]}_#{authoritative_result[:associated_asset_id]}_#{authoritative_result[:external_outcome_id]}_#{authoritative_result[:user_uuid]}"
            assignment = assignments[authoritative_result[:associated_asset_id].to_s]
            outcome = outcomes[authoritative_result[:external_outcome_id].to_s]
            if student_results.key?(composite_key)
              # This should not happen, but if it does we take the result that was submitted last.
              current_result = student_results[composite_key].first
              if current_result && authoritative_result[:submitted_at] > current_result["result submitted at"]
                student_results[composite_key] = decorate_result(account, course, assignment, outcome, authoritative_result)
              end
            else
              student_results[composite_key] = decorate_result(account, course, assignment, outcome, authoritative_result)
            end
          end
        end

        sort_order = map_order_to_columns(outcome_order)
        student_results.values.flatten.sort do |s1, s2|
          comparator = 0
          sort_order.each do |s|
            comparator = s1[s] <=> s2[s]
            break unless comparator == 0
          end
          comparator
        end
      end

      def outcome_results_scope
        students = account.learning_outcome_links.active
                          .select(<<~SQL.squish)
                            distinct on (#{outcome_order}, p.id, s.id, r.id, qr.id, q.id, a.id, subs.id, qs.id, aq.id)
                            u.sortable_name                             AS "student name",
                            p.user_id                                   AS "student id",
                            p.sis_user_id                               AS "student sis id",
                            a.id                                        AS "assignment id",
                            COALESCE(q.title, a.title)                  AS "assessment title",
                            COALESCE(q.id, a.id)                        AS "assessment id",
                            COALESCE(qs.finished_at, subs.submitted_at) AS "submission date",
                            COALESCE(qs.score, subs.score)              AS "submission score",
                            aq.name                                     AS "assessment question",
                            aq.id                                       AS "assessment question id",
                            learning_outcomes.short_description         AS "learning outcome name",
                            learning_outcomes.id                        AS "learning outcome id",
                            learning_outcomes.display_name              AS "learning outcome friendly name",
                            COALESCE(qr.possible, r.possible)           AS "learning outcome points possible",
                            COALESCE(qr.mastery, r.mastery)             AS "learning outcome mastered",
                            learning_outcomes.data                      AS "learning outcome data",
                            g.title                                     AS "learning outcome group title",
                            g.id                                        AS "learning outcome group id",
                            COALESCE(qr.attempt, r.attempt)             AS "attempt",
                            r.hide_points                               AS "learning outcome points hidden",
                            COALESCE(qr.score, r.score)                 AS "outcome score",
                            r.percent                                   AS "total percent outcome score",
                            c.name                                      AS "course name",
                            c.id                                        AS "course id",
                            c.sis_source_id                             AS "course sis id",
                            CASE WHEN r.association_type IN ('Quiz', 'Quizzes::Quiz') THEN 'quiz'
                                WHEN ct.content_type = 'Assignment' THEN 'assignment'
                            END                                         AS "assessment type",
                            s.name                                      AS "section name",
                            s.id                                        AS "section id",
                            s.sis_source_id                             AS "section sis id",
                            e.workflow_state                            AS "enrollment state",
                            acct.id                                     AS "account id",
                            acct.name                                   AS "account name"
                          SQL
                          .joins(<<~SQL.squish)
                            INNER JOIN #{LearningOutcomeGroup.quoted_table_name} g ON g.id = content_tags.associated_asset_id
                              AND content_tags.associated_asset_type = 'LearningOutcomeGroup'
                            INNER JOIN #{LearningOutcome.quoted_table_name} ON content_tags.content_id = learning_outcomes.id
                              AND content_tags.content_type = 'LearningOutcome'
                            INNER JOIN #{LearningOutcomeResult.quoted_table_name} r ON r.learning_outcome_id = learning_outcomes.id
                            INNER JOIN #{ContentTag.quoted_table_name} ct ON r.content_tag_id = ct.id
                            INNER JOIN #{User.quoted_table_name} u ON u.id = r.user_id
                            INNER JOIN #{Pseudonym.quoted_table_name} p on p.user_id = r.user_id
                            INNER JOIN #{Course.quoted_table_name} c ON r.context_id = c.id
                            INNER JOIN #{Account.quoted_table_name} acct ON acct.id = c.account_id
                            INNER JOIN #{Enrollment.quoted_table_name} e ON e.type = 'StudentEnrollment' and e.root_account_id = #{account.root_account.id}
                              AND e.user_id = p.user_id AND e.course_id = c.id
                              #{"AND e.workflow_state <> 'deleted'" unless @include_deleted}
                            INNER JOIN #{CourseSection.quoted_table_name} s ON e.course_section_id = s.id
                            LEFT OUTER JOIN #{LearningOutcomeQuestionResult.quoted_table_name} qr on qr.learning_outcome_result_id = r.id
                            LEFT OUTER JOIN #{Quizzes::Quiz.quoted_table_name} q ON q.id = r.association_id
                            AND r.association_type IN ('Quiz', 'Quizzes::Quiz')
                            LEFT OUTER JOIN #{Assignment.quoted_table_name} a ON a.type = 'Assignment' AND ((a.id = ct.content_id
                            AND ct.content_type = 'Assignment') OR a.id = q.assignment_id)
                            LEFT OUTER JOIN #{Submission.quoted_table_name} subs ON subs.assignment_id = a.id
                            AND subs.user_id = u.id AND subs.workflow_state <> 'deleted' AND subs.workflow_state <> 'unsubmitted'
                            LEFT OUTER JOIN #{Quizzes::QuizSubmission.quoted_table_name} qs ON r.artifact_id = qs.id
                            AND r.artifact_type IN ('QuizSubmission', 'Quizzes::QuizSubmission')
                            LEFT OUTER JOIN #{AssessmentQuestion.quoted_table_name} aq ON aq.id = qr.associated_asset_id
                            AND qr.associated_asset_type = 'AssessmentQuestion'
                          SQL
                          .where("ct.workflow_state <> 'deleted' AND r.workflow_state <> 'deleted' AND r.artifact_type <> 'Submission'")

        unless @include_deleted
          students = students.where("p.workflow_state<>'deleted' AND c.workflow_state IN ('available', 'completed')")
        end

        students = join_course_sub_account_scope(account, students, "c")
        students = add_term_scope(students, "c")
        students.order(outcome_order)
      end
    end
  end
end
