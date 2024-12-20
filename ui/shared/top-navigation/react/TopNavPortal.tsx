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

import React from 'react'
import {Portal} from '@instructure/ui-portal'
import TopNav, {type ITopNavProps} from './TopNav'
import {QueryProvider} from '@canvas/query'
import ReactDOM from 'react-dom'
import {createRoot} from 'react-dom/client'
import TopNavPortalWithDefaults from '@canvas/top-navigation/react/TopNavPortalWithDefaults'

const getMountPoint = (): HTMLElement | null => document.getElementById('react-instui-topnav')

const TopNavPortal: React.FC<ITopNavProps> = props => {
  const mountPoint = getMountPoint()
  if (!mountPoint) {
    return null
  }

  return (
    <Portal open={true} mountNode={mountPoint}>
      <QueryProvider>
        <TopNav {...props} />
      </QueryProvider>
    </Portal>
  )
}
export const initializeTopNavPortal = (props?: ITopNavProps): void => {
  const mountPoint = getMountPoint()
  if (mountPoint) {
    const root = createRoot(mountPoint)
    root.render(<TopNavPortal {...props} />)
  }
}

export default TopNavPortal
