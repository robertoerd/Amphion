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

require "rubygems"
require "zip"

# Call this with a block.  The block will take an array of filenames
# extracted.  Once this block is executed, these extracted files and
# their directory are destroyed. An example:
# ZipExtractor.call(@zip_filename) {|list|
#   list.each {|f| FileInContext.attach(@context, f)}
# }
# That example takes all the files in a zipped directory and attaches
# them to a context.
class ZipExtractor
  class << self
    def call(filename, &)
      ze = new(filename)
      ze.unzip_files(&)
    end
  end

  attr_reader :filename, :unzipped_files

  def initialize(filename)
    @filename = filename
  end

  # Grabs all files and dumps them into a temporary directory.
  def unzip_files(&block)
    @unzipped_files = []
    CanvasUnzip.extract_archive(@filename) do |zip_entry|
      next if zip_entry.directory?

      local_name = File.join(dirname, File.split(zip_entry.name).last)
      zip_entry.extract(local_name)
      unzipped_files << local_name
    end
    block&.call(unzipped_files)
    unzipped_files
  end

  def remove_extracted_files!
    FileUtils.rm_rf(dirname)
  end

  def dirname
    @dirname ||= Dir.mktmpdir
  end
end
