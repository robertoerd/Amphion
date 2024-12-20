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

import CanvasMultiSelect, {type Size} from '@canvas/multi-select/react'
import React, {type ReactElement, useEffect, useRef, useState, useCallback, useMemo} from 'react'
import {useScope as useI18nScope} from '@canvas/i18n'
import {Link} from '@instructure/ui-link'
import {View} from '@instructure/ui-view'
import {Text} from '@instructure/ui-text'
import {debounce} from 'lodash'
import {ScreenReaderContent} from '@instructure/ui-a11y-content'
import {setContainScrollBehavior} from '../utils/assignToHelper'
import useFetchAssignees from '../utils/hooks/useFetchAssignees'
import type {FormMessage} from '@instructure/ui-form-field'
import {showFlashAlert} from '@canvas/alerts/react/FlashAlert'
import type {AssigneeOption} from './Item/types'
import type {ItemType} from './types'
import {Spinner} from '@instructure/ui-spinner'

const {Option: CanvasMultiSelectOption} = CanvasMultiSelect as any

const I18n = useI18nScope('differentiated_modules')

interface Props {
  courseId: string
  onSelect: (options: AssigneeOption[]) => void
  defaultValues: AssigneeOption[]
  selectedOptionIds: string[]
  clearAllDisabled?: boolean
  size?: Size
  messages?: FormMessage[]
  disabledOptionIds?: string[]
  everyoneOption?: AssigneeOption
  disableFetch?: boolean // avoid mutating the state when closing the tray
  customAllOptions?: AssigneeOption[]
  customIsLoading?: boolean
  customSetSearchTerm?: (term: string) => void
  onError?: () => void
  showVisualLabel?: boolean
  inputRef?: (inputElement: HTMLInputElement | null) => void
  onBlur?: () => void
  disabledWithGradingPeriod?: boolean
  disabledOptionIdsRef?: React.MutableRefObject<string[]>
  itemType?: ItemType
}

const AssigneeSelector = ({
  courseId,
  onSelect,
  defaultValues,
  selectedOptionIds = [],
  clearAllDisabled,
  size = 'large',
  messages,
  disabledOptionIds = [],
  disableFetch = false,
  everyoneOption,
  customAllOptions,
  customIsLoading,
  customSetSearchTerm,
  onError,
  showVisualLabel = true,
  inputRef,
  onBlur,
  disabledWithGradingPeriod,
  disabledOptionIdsRef,
  itemType,
}: Props) => {
  const listElementRef = useRef<HTMLElement | null>(null)
  const [options, setOptions] = useState<AssigneeOption[]>(defaultValues)
  const {allOptions, isLoading, setSearchTerm} = useFetchAssignees({
    courseId,
    everyoneOption,
    defaultValues,
    disableFetch,
    customAllOptions,
    customIsLoading,
    customSetSearchTerm,
    onError,
  })
  const [highlightedOptionId, setHighlightedOptionId] = useState<string | null>(null)
  const disabledOptions = disabledOptionIdsRef?.current ?? disabledOptionIds

  const shouldUpdateOptions = [
    JSON.stringify(allOptions),
    JSON.stringify(disabledOptions),
    JSON.stringify(selectedOptionIds),
  ]

  useEffect(() => {
    const newOptions = allOptions.filter(
      option => selectedOptionIds.includes(option.id) || !disabledOptions.includes(option.id)
    )
    setOptions(newOptions)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, shouldUpdateOptions)

  const handleChange = (newSelected: string[]) => {
    const newSelectedSet = new Set(newSelected)
    const selected = options.filter(option => newSelectedSet.has(option.id))
    onSelect(selected)
  }

  const handleInputChange = debounce(value => setSearchTerm(value), 500)

  const handleShowOptions = () => {
    setTimeout(() => {
      setContainScrollBehavior(listElementRef.current)
    }, 500)
  }

  const handleClear = () => {
    onSelect([])
    showFlashAlert({message: I18n.t('All assignees removed'), srOnly: true})
  }

  const label = I18n.t('Assign To')

  const optionMatcher = (
    option: {
      id: string
    },
    term: string
  ): boolean => {
    const selectedOption = allOptions.find(o => o.id === option.id)
    return (
      selectedOption?.value.toLowerCase().includes(term.toLowerCase()) ||
      selectedOption?.sisID?.toLowerCase().includes(term.toLowerCase()) ||
      false
    )
  }

  const handleFocus = useCallback(() => {
    const newOptions = allOptions.filter(
      option => selectedOptionIds.includes(option.id) || !disabledOptions.includes(option.id)
    )
    setOptions(newOptions)
  }, [allOptions, selectedOptionIds, disabledOptions])

  const shouldDisableSelector = useMemo(() => {
    if (!(itemType === 'discussion' || itemType === 'discussion_topic')) return false
    return ENV?.current_user_is_student
  }, [itemType])

  return (
    <>
      <CanvasMultiSelect
        disabled={disabledWithGradingPeriod || shouldDisableSelector}
        data-testid="assignee_selector"
        messages={messages}
        label={showVisualLabel ? label : <ScreenReaderContent>{label}</ScreenReaderContent>}
        size={size}
        selectedOptionIds={selectedOptionIds}
        onChange={handleChange}
        renderAfterInput={
          isLoading ? (
            <Spinner
              renderTitle={
                <ScreenReaderContent>
                  {I18n.t('Loading student, section, and group data')}
                </ScreenReaderContent>
              }
              size="x-small"
            />
          ) : (
            <></>
          )
        }
        customOnInputChange={handleInputChange}
        visibleOptionsCount={10}
        isLoading={isLoading}
        isRequired={true}
        setInputRef={inputRef}
        listRef={e => (listElementRef.current = e)}
        customOnRequestShowOptions={handleShowOptions}
        // @ts-expect-error
        onFocus={handleFocus}
        customRenderBeforeInput={tags =>
          tags?.map((tag: ReactElement) => (
            <View
              key={tag.key}
              data-testid="assignee_selector_selected_option"
              as="div"
              display="inline-block"
              margin="xx-small none"
            >
              {tag}
            </View>
          ))
        }
        customMatcher={optionMatcher}
        onUpdateHighlightedOption={setHighlightedOptionId}
        customOnBlur={onBlur}
      >
        {options.map(option => {
          return (
            <CanvasMultiSelectOption
              id={option.id}
              value={option.id}
              key={option.id}
              group={option.group}
              tagText={option.value}
            >
              <Text as="div">{option.value}</Text>
              {option.sisID && (
                <Text
                  as="div"
                  size="small"
                  color={highlightedOptionId === option.id ? 'secondary-inverse' : 'secondary'}
                >
                  {option.sisID}
                </Text>
              )}
            </CanvasMultiSelectOption>
          )
        })}
      </CanvasMultiSelect>
      {!clearAllDisabled && (
        <View as="div" textAlign="end" margin="small none">
          <Link data-testid="clear_selection_button" onClick={handleClear} isWithinText={false}>
            <span aria-hidden={true}>{I18n.t('Clear All')}</span>
            <ScreenReaderContent>{I18n.t('Clear Assign To')}</ScreenReaderContent>
          </Link>
        </View>
      )}
    </>
  )
}

export default AssigneeSelector
