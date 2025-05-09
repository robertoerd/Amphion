/*
 * Copyright (C) 2024 - present Instructure, Inc.
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
import type {DynamicRegistrationOverlayStore} from '../DynamicRegistrationOverlayState'
import {useOverlayStore} from '../hooks/useOverlayStore'
import type {DynamicRegistrationActions} from '../DynamicRegistrationWizardState'
import {IconConfirmation} from '../../registration_wizard_forms/IconConfirmation'
import type {LtiRegistrationWithConfiguration} from '../../model/LtiRegistration'
import {
  type LtiPlacement,
  LtiPlacementsWithIcons,
  type LtiPlacementWithIcon,
} from '../../model/LtiPlacement'
export type IconConfirmationProps = {
  overlayStore: DynamicRegistrationOverlayStore
  registration: LtiRegistrationWithConfiguration
  reviewing: boolean
  transitionToConfirmationState: DynamicRegistrationActions['transitionToConfirmationState']
  transitionToReviewingState: DynamicRegistrationActions['transitionToReviewingState']
}

export const IconConfirmationWrapper = ({
  overlayStore,
  registration,
  reviewing,
  transitionToConfirmationState,
  transitionToReviewingState,
}: IconConfirmationProps) => {
  const [overlayState, actions] = useOverlayStore(overlayStore)
  const placements = registration.configuration.placements.map(p => p.placement)
  const iconPlacements = React.useMemo(
    () =>
      placements.filter((p): p is LtiPlacementWithIcon =>
        LtiPlacementsWithIcons.includes(p as LtiPlacementWithIcon),
      ),
    [placements],
  )
  const placementsWithUrls = iconPlacements.reduce((acc, placement) => {
    const iconUrl = overlayState.overlay.placements?.[placement]?.icon_url
    return {
      ...acc,
      [placement]: iconUrl ?? '',
    }
  }, {})

  return (
    <IconConfirmation
      allPlacements={placements}
      internalConfig={registration.configuration}
      name={overlayState.adminNickname ?? registration.name}
      placementIconOverrides={placementsWithUrls}
      onPreviousButtonClicked={() =>
        transitionToConfirmationState('IconConfirmation', 'NamingConfirmation')
      }
      onNextButtonClicked={() => transitionToReviewingState('IconConfirmation')}
      reviewing={reviewing}
      setPlacementIconUrl={actions.updateIconUrl}
      developerKeyId={registration.developer_key_id ?? undefined}
    />
  )
}
