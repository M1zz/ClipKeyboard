#!/usr/bin/env ruby
# ClipKeyboardShareExtension를 빌드 타겟으로 등록한다.
# (소스/Info.plist/entitlements는 이미 작성돼 있고 타겟만 없던 상태 — README 참고)
require "xcodeproj"

PROJ = "ClipKeyboard.xcodeproj"
TEAM = "QGAQ3AY3R3"
proj = Xcodeproj::Project.open(PROJ)
app  = proj.targets.find { |t| t.name == "ClipKeyboard" }
raise "main app target not found" unless app

if proj.targets.any? { |t| t.name == "ClipKeyboardShareExtension" }
  puts "already registered — nothing to do"; exit 0
end

# 1) 앱 익스텐션 타겟 생성 (.appex)
ext = proj.new_target(:app_extension, "ClipKeyboardShareExtension", :ios, "26.0")

# 2) 그룹 + 파일 참조 (폴더는 이미 존재)
grp = proj.main_group.new_group("ClipKeyboardShareExtension", "ClipKeyboardShareExtension")
svc   = grp.new_reference("ShareViewController.swift")
grp.new_reference("Info.plist")
grp.new_reference("ClipKeyboardShareExtension.entitlements")
grp.new_reference("README.md")

# 3) 소스 컴파일 대상에 추가
ext.source_build_phase.add_file_reference(svc)

# 4) 빌드 설정 (Debug/Release 공통)
ext.build_configurations.each do |c|
  bs = c.build_settings
  bs["PRODUCT_BUNDLE_IDENTIFIER"] = "com.Ysoup.TokenMemo.share"
  bs["INFOPLIST_FILE"]            = "ClipKeyboardShareExtension/Info.plist"
  bs["CODE_SIGN_ENTITLEMENTS"]    = "ClipKeyboardShareExtension/ClipKeyboardShareExtension.entitlements"
  bs["GENERATE_INFOPLIST_FILE"]  = "NO"     # 자체 Info.plist(NSExtension) 사용
  bs["DEVELOPMENT_TEAM"]         = TEAM
  bs["CODE_SIGN_STYLE"]          = "Automatic"
  bs["MARKETING_VERSION"]        = "4.3.4"
  bs["CURRENT_PROJECT_VERSION"]  = "1"
  bs["IPHONEOS_DEPLOYMENT_TARGET"] = "26.0"
  bs["SWIFT_VERSION"]            = "5.0"
  bs["TARGETED_DEVICE_FAMILY"]   = "1,2"
  bs["PRODUCT_NAME"]             = "$(TARGET_NAME)"
  bs["SWIFT_EMIT_LOC_STRINGS"]   = "YES"
  bs["LD_RUNPATH_SEARCH_PATHS"]  = ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
end

# 5) 메인 앱이 익스텐션에 의존 + 기존 Embed 단계에 .appex 포함
app.add_dependency(ext)
embed = app.copy_files_build_phases.find { |ph| ph.dst_subfolder_spec == "13" } # 13 = PlugIns
raise "embed phase not found" unless embed
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

proj.save

# 검증 출력
puts "registered ClipKeyboardShareExtension"
t = proj.targets.find { |x| x.name == "ClipKeyboardShareExtension" }
puts "  product: #{t.product_reference.path}"
puts "  sources: #{t.source_build_phase.files.map { |f| f.file_ref&.path }.compact.join(', ')}"
puts "  app deps: #{app.dependencies.map { |d| d.target.name }.join(', ')}"
puts "  embedded in app: #{embed.files.map { |f| f.file_ref&.path }.compact.join(', ')}"
