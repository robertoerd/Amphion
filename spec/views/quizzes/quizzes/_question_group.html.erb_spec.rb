# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
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

require_relative "../../views_helper"

describe "quizzes/quizzes/_question_group" do
  it "renders" do
    course_with_student
    view_context
    assign(:quiz, @course.quizzes.create!)
    group = {}
    group[:id] = 5
    group[:questions] = []
    render partial: "quizzes/quizzes/question_group", object: group, locals: { question_type: QuizzesHelper::QuestionType.new }
    expect(response).not_to be_nil
  end
end
