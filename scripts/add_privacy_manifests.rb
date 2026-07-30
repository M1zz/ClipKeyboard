#!/usr/bin/env ruby
# PrivacyInfo.xcprivacy 를 각 타겟의 Copy Bundle Resources 에 등록한다.
# xcodeproj gem 사용 — 손편집보다 안전. 멱등(이미 있으면 건너뜀).
#
# 매니페스트는 **번들에 복사돼야** 심사·개인정보 리포트에서 인식된다.
# 타겟마다 파일이 따로 있어야 한다(앱 하나에 몰아넣으면 익스텐션 것은 비어 있는 것으로 처리됨).
require 'xcodeproj'

PROJECT = 'ClipKeyboard.xcodeproj'

# 타겟명 => 매니페스트 경로(프로젝트 루트 기준)
#
# ⚠️ widgetExtension 은 여기 없다 — `widget/` 이 Xcode 16 동기화 그룹
#    (PBXFileSystemSynchronizedRootGroup)이라 폴더 안의 파일이 자동으로 타겟에 포함된다.
#    (예외는 membershipExceptions 의 Info.plist 하나뿐)
#    즉 widget/PrivacyInfo.xcprivacy 는 **파일을 두는 것만으로** 번들에 들어간다.
#    pbxproj 에 억지로 등록하면 중복 리소스가 된다.
MANIFESTS = {
  'ClipKeyboard'               => 'ClipKeyboard/PrivacyInfo.xcprivacy',
  'ClipKeyboardExtension'      => 'ClipKeyboardExtension/PrivacyInfo.xcprivacy',
  'ClipKeyboardShareExtension' => 'ClipKeyboardShareExtension/PrivacyInfo.xcprivacy'
}.freeze

project = Xcodeproj::Project.open(PROJECT)
changed = false

MANIFESTS.each do |target_name, path|
  target = project.targets.find { |t| t.name == target_name }
  abort("❌ 타겟을 찾을 수 없음: #{target_name}") if target.nil?
  abort("❌ 파일이 없음: #{path}") unless File.exist?(path)

  # 이미 리소스에 들어 있으면 건너뛴다.
  already = target.resources_build_phase.files.any? do |bf|
    bf.file_ref && bf.file_ref.real_path.to_s.end_with?(path)
  end
  if already
    puts "⏭  #{target_name}: 이미 등록됨"
    next
  end

  # 기존 file_ref 재사용, 없으면 해당 그룹(없으면 루트)에 추가.
  ref = project.files.find { |f| f.real_path.to_s.end_with?(path) }
  if ref.nil?
    group_name = File.dirname(path)
    group = project.groups.find { |g| g.display_name == group_name } ||
            project.main_group.find_subpath(group_name, true)
    ref = group.new_reference(File.basename(path))
  end

  target.resources_build_phase.add_file_reference(ref, true)
  changed = true
  puts "✅ #{target_name}: #{path} 등록"
end

if changed
  project.save
  puts "💾 #{PROJECT} 저장 완료"
else
  puts "변경 없음"
end
