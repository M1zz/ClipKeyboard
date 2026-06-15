#!/usr/bin/env ruby
# Register sync files into the right targets, mirroring an anchor file's group/targets.
require "xcodeproj"

proj = Xcodeproj::Project.open("ClipKeyboard.xcodeproj")

def target_names(proj, ref)
  proj.targets.select { |t| t.source_build_phase.files.any? { |bf| bf.file_ref == ref } }.map(&:name)
end

def add(proj, filename, anchor_basename, want_targets)
  anchor = proj.files.find { |f| f.path && f.path.end_with?(anchor_basename) }
  raise "anchor not found: #{anchor_basename}" unless anchor
  group = anchor.parent
  ref = group.files.find { |f| f.path == filename } || group.new_reference(filename)
  want_targets.each do |tn|
    t = proj.targets.find { |x| x.name == tn } or raise "no target #{tn}"
    unless t.source_build_phase.files.any? { |bf| bf.file_ref == ref }
      t.add_file_references([ref])
      puts "  + #{tn} <- #{filename}"
    end
  end
end

# MemoSyncCore.swift: same group/targets as MemoStore.swift (iOS), plus Mac target.
# (ClipKeyboardTests is a synchronized folder group → test file auto-included, no entry needed.)
add(proj, "MemoSyncCore.swift", "MemoStore.swift", %w[ClipKeyboard ClipKeyboard.tap])

proj.save
puts "saved."
%w[MemoSyncCore.swift].each do |fn|
  ref = proj.files.find { |f| f.path == fn }
  puts "#{fn}: #{target_names(proj, ref).join(', ')}"
end
