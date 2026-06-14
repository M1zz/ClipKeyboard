#!/usr/bin/env ruby
# LeeoKit 로컬 SPM 패키지를 ClipKeyboard 프로젝트의 지정 타겟에 연결한다.
# xcodeproj gem 사용 — 손편집보다 안전. 멱등(이미 있으면 건너뜀).
require 'xcodeproj'

PROJECT = 'ClipKeyboard.xcodeproj'
REL_PATH = '../LeeoKit'
PRODUCT  = 'LeeoKit'
TARGETS  = %w[ClipKeyboard ClipKeyboardExtension]

project = Xcodeproj::Project.open(PROJECT)

# 1. 로컬 패키지 레퍼런스 (없으면 생성)
local_ref = project.root_object.package_references.find do |r|
  r.is_a?(Xcodeproj::Project::Object::XCLocalSwiftPackageReference) && r.relative_path == REL_PATH
end
if local_ref.nil?
  local_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  local_ref.relative_path = REL_PATH
  project.root_object.package_references << local_ref
  puts "✅ 로컬 패키지 레퍼런스 추가: #{REL_PATH}"
else
  puts "↩️  로컬 패키지 레퍼런스 이미 존재"
end

# 2. 타겟별 product dependency + Frameworks 빌드파일
TARGETS.each do |tname|
  target = project.targets.find { |t| t.name == tname }
  raise "타겟 없음: #{tname}" if target.nil?

  already = target.package_product_dependencies.any? { |d| d.product_name == PRODUCT }
  if already
    puts "↩️  [#{tname}] 이미 #{PRODUCT} 연결됨"
    next
  end

  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.product_name = PRODUCT
  dep.package = local_ref
  target.package_product_dependencies << dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  target.frameworks_build_phase.files << build_file

  puts "✅ [#{tname}] #{PRODUCT} 연결 완료"
end

project.save
puts "💾 저장 완료"
