#!/usr/bin/env ruby
# Add the central constant files to the same targets as AppGroup.swift.
require "xcodeproj"

proj_path = "ClipKeyboard.xcodeproj"
proj = Xcodeproj::Project.open(proj_path)

NEW_FILES = %w[AppSymbol.swift DefaultsKey.swift AppNotification.swift StorageFile.swift]
TARGET_NAMES = %w[ClipKeyboard ClipKeyboardExtension ClipKeyboard.tap]

# Group that holds AppGroup.swift
anchor = proj.files.find { |f| f.path && f.path.end_with?("AppGroup.swift") }
group = anchor.parent
targets = TARGET_NAMES.map { |n| proj.targets.find { |t| t.name == n } }

NEW_FILES.each do |fname|
  existing = group.files.find { |f| f.path == fname }
  if existing
    puts "skip (already in group): #{fname}"
    ref = existing
  else
    ref = group.new_reference(fname)
    puts "added file ref: #{fname}"
  end
  targets.each do |t|
    already = t.source_build_phase.files.any? { |bf| bf.file_ref == ref }
    unless already
      t.add_file_references([ref])
      puts "  + #{t.name}"
    end
  end
end

proj.save
puts "saved #{proj_path}"
