#!/usr/bin/env ruby
# ClipKeyboardActionExtension을 빌드 타겟으로 등록한다.
#
# 왜 필요한가: 공유 확장(com.apple.share-services)은 공유 시트 **윗줄(앱)** 에만 나온다.
# 아래 동작 목록에 나오려면 동작 확장(com.apple.ui-services)이 별도 타겟이어야 한다.
#
# 소스/Info.plist/entitlements는 이미 작성돼 있고 타겟만 없는 상태에서 돌린다.
# (add_share_extension.rb 와 같은 방식 - 그쪽 설정을 그대로 따른다)
require "xcodeproj"

PROJ = "ClipKeyboard.xcodeproj"
TEAM = "QGAQ3AY3R3"
NAME = "ClipKeyboardActionExtension"

proj = Xcodeproj::Project.open(PROJ)
app  = proj.targets.find { |t| t.name == "ClipKeyboard" }
raise "main app target not found" unless app

if proj.targets.any? { |t| t.name == NAME }
  puts "already registered - nothing to do"; exit 0
end

# 1) 앱 익스텐션 타겟 생성 (.appex)
ext = proj.new_target(:app_extension, NAME, :ios, "26.0")

# 2) 그룹 + 파일 참조 (폴더는 이미 존재)
grp = proj.main_group.new_group(NAME, NAME)
vc  = grp.new_reference("ActionViewController.swift")
grp.new_reference("Info.plist")
grp.new_reference("#{NAME}.entitlements")

# 3) 저장 로직은 공유 확장과 **같은 파일**을 쓴다 - 스키마를 아는 곳은 하나여야 한다.
shared_grp = proj.main_group.find_subpath("Shared", true)
shared_grp.set_source_tree("<group>")
shared_grp.set_path("Shared")
save_ref = shared_grp.files.find { |f| f.path == "QuickShortcutSave.swift" } ||
           shared_grp.new_reference("QuickShortcutSave.swift")

ext.source_build_phase.add_file_reference(vc)
ext.source_build_phase.add_file_reference(save_ref)

# 공유 확장에도 같은 파일을 물린다 (아직 안 물려 있으면).
share = proj.targets.find { |t| t.name == "ClipKeyboardShareExtension" }
if share && share.source_build_phase.files.none? { |f| f.file_ref&.path == "QuickShortcutSave.swift" }
  share.source_build_phase.add_file_reference(save_ref)
  puts "  + QuickShortcutSave.swift → ClipKeyboardShareExtension"
end

# 4) 문자열 카탈로그 - 목록에 적히는 이름이 번역되도록 리소스로 넣는다.
strings = proj.files.find { |f| f.path&.end_with?("Localizable.xcstrings") }
ext.resources_build_phase.add_file_reference(strings) if strings

# 5) 빌드 설정 (공유 확장과 동일 규격)
ext.build_configurations.each do |c|
  bs = c.build_settings
  bs["PRODUCT_BUNDLE_IDENTIFIER"]  = "com.Ysoup.TokenMemo.action"
  bs["INFOPLIST_FILE"]             = "#{NAME}/Info.plist"
  bs["CODE_SIGN_ENTITLEMENTS"]     = "#{NAME}/#{NAME}.entitlements"
  bs["GENERATE_INFOPLIST_FILE"]    = "NO"     # 자체 Info.plist(NSExtension) 사용
  bs["DEVELOPMENT_TEAM"]           = TEAM
  bs["CODE_SIGN_STYLE"]            = "Automatic"
  bs["MARKETING_VERSION"]          = "$(MARKETING_VERSION)"
  bs["CURRENT_PROJECT_VERSION"]    = "$(CURRENT_PROJECT_VERSION)"
  bs["IPHONEOS_DEPLOYMENT_TARGET"] = "26.0"
  bs["SWIFT_VERSION"]              = "5.0"
  bs["TARGETED_DEVICE_FAMILY"]     = "1,2"
  bs["PRODUCT_NAME"]               = "$(TARGET_NAME)"
  bs["SWIFT_EMIT_LOC_STRINGS"]     = "YES"
  bs["LD_RUNPATH_SEARCH_PATHS"]    = ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
end

# 6) 메인 앱이 익스텐션에 의존 + 기존 Embed 단계에 .appex 포함
app.add_dependency(ext)
embed = app.copy_files_build_phases.find { |ph| ph.dst_subfolder_spec == "13" } # 13 = PlugIns
raise "embed phase not found" unless embed
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

proj.save

puts "registered #{NAME}"
t = proj.targets.find { |x| x.name == NAME }
puts "  product: #{t.product_reference.path}"
puts "  sources: #{t.source_build_phase.files.map { |f| f.file_ref&.path }.compact.join(', ')}"
puts "  embedded in app: #{embed.files.map { |f| f.file_ref&.path }.compact.join(', ')}"
