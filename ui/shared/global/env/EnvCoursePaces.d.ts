/*
 * Copyright (C) 2023 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import {Course} from '../../../features/course_paces/react/shared/types'
import {CoursePace, PaceContextProgress, Progress} from '../../../features/course_paces/react/types'
import {EnvDateRange} from '../DateRange'

export type MasterCourseData = {
  is_master_course_child_content?: boolean
  is_master_course_master_content?: boolean
  master_course_restrictions: unknown
  restricted_by_master_course: boolean
}
/**
 * Course Paces environment variables
 *
 * From CoursePacesController#index
 */
export interface EnvCoursePaces {
  BLACKOUT_DATES: unknown
  CALENDAR_EVENT_BLACKOUT_DATES: unknown
  ENROLLMENTS: unknown
  SECTIONS: unknown
  COURSE: Course
  COURSE_ID: string
  COURSE_PACE_ID: string
  /**
   * Course Pace object
   *
   * NOTE: This may or may not be the right type. This value is generated by CoursePacePresenter
   */
  COURSE_PACE: CoursePace
  COURSE_PACE_PROGRESS: Progress
  VALID_DATE_RANGE: EnvDateRange
  MASTER_COURSE_DATA: MasterCourseData
  IS_MASQUERADING: boolean
  PACES_PUBLISHING: PaceContextProgress[]
}
