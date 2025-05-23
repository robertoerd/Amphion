/*
 * Copyright (C) 2018 - present Instructure, Inc.
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

import $ from 'jquery'
import htmlEscape, {unescape} from '@instructure/html-escape'

const equal = (a, b) => expect(a).toBe(b)
const strictEqual = (a, b) => expect(a).toBe(b)

describe('htmlEscape', () => {
  describe('.htmlEscape()', () => {
    test('replaces "&" with "&amp;"', () => {
      equal(htmlEscape('foo & bar'), 'foo &amp; bar')
    })

    test('replaces "<" with "&lt;"', () => {
      equal(htmlEscape('foo < bar'), 'foo &lt; bar')
    })

    test('replaces ">" with "&gt;"', () => {
      equal(htmlEscape('foo > bar'), 'foo &gt; bar')
    })

    test('replaces " with "&quot;"', () => {
      equal(htmlEscape('foo " bar'), 'foo &quot; bar')
    })

    test('replaces \' with "&#x27;"', () => {
      equal(htmlEscape("foo ' bar"), 'foo &#x27; bar')
    })

    test('replaces "/" with "&#x2F;"', () => {
      equal(htmlEscape('foo / bar'), 'foo &#x2F; bar')
    })

    test('replaces "`" with "&#x60;"', () => {
      equal(htmlEscape('foo ` bar'), 'foo &#x60; bar')
    })

    test('replaces "=" with "&#x3D;"', () => {
      equal(htmlEscape('foo = bar'), 'foo &#x3D; bar')
    })

    test('replaces any combination of known replaceable values', () => {
      const value = '& < > " \' / ` ='
      equal(htmlEscape(value), '&amp; &lt; &gt; &quot; &#x27; &#x2F; &#x60; &#x3D;')
    })

    test('htmlEscape with jQuery object', function () {
      const $regradeInfoSpan = $('<span id="regrade_info_span">This is a test</span>')
      // attempt to escape jQuery object, this should be a no-op
      const result = htmlEscape($regradeInfoSpan)

      strictEqual(
        result,
        $regradeInfoSpan,
        `Passing a jQuery object should return ${$regradeInfoSpan}`,
      )
    })
  })

  describe('.unescape()', () => {
    test('replaces "&amp;" with "&"', () => {
      equal(unescape('foo &amp; bar'), 'foo & bar')
    })

    test('replaces "&lt;" with "<"', () => {
      equal(unescape('foo &lt; bar'), 'foo < bar')
    })

    test('replaces "&gt;" with ">"', () => {
      equal(unescape('foo &gt; bar'), 'foo > bar')
    })

    test('replaces "&quot;" with "', () => {
      equal(unescape('foo &quot; bar'), 'foo " bar')
    })

    test('replaces "&#x27;" with \'', () => {
      equal(unescape('foo &#x27; bar'), "foo ' bar")
    })

    test('replaces "&#x2F;" with "/"', () => {
      equal(unescape('foo &#x2F; bar'), 'foo / bar')
    })

    test('replaces "&#x60;" with "`"', () => {
      equal(unescape('foo &#x60; bar'), 'foo ` bar')
    })

    test('replaces "&#x3D;" with "="', () => {
      equal(unescape('foo &#x3D; bar'), 'foo = bar')
    })

    test('replaces any combination of known replaceable values', () => {
      const value = '&amp; &lt; &gt; &quot; &#x27; &#x2F; &#x60; &#x3D;'
      equal(unescape(value), '& < > " \' / ` =')
    })
  })
})
