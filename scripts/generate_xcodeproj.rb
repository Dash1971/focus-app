#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'
require 'fileutils'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'FocusApp.xcodeproj')
FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2600'
project.root_object.attributes['LastUpgradeCheck'] = '2600'

def configure(target, bundle_id:, plist: nil, entitlements: nil)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1'
    settings['SWIFT_VERSION'] = '5.0'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['CURRENT_PROJECT_VERSION'] = '5'
    settings['MARKETING_VERSION'] = '0.4.0'
    settings['CODE_SIGN_ENTITLEMENTS'] = entitlements if entitlements
    if plist
      settings['GENERATE_INFOPLIST_FILE'] = 'NO'
      settings['INFOPLIST_FILE'] = plist
    else
      settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    end
  end
end

def add_sources(project, target, paths)
  paths.each do |path|
    ref = project.main_group.find_file_by_path(path) || project.main_group.new_file(path)
    target.source_build_phase.add_file_reference(ref)
  end
end

def add_resources(project, target, paths)
  paths.each do |path|
    ref = project.main_group.find_file_by_path(path) || project.main_group.new_file(path)
    target.resources_build_phase.add_file_reference(ref)
  end
end

def add_framework(project, target, name)
  ref = project.frameworks_group.files.find { |file| file.path == name } || project.frameworks_group.new_file("System/Library/Frameworks/#{name}")
  target.frameworks_build_phase.add_file_reference(ref, true)
end

models = 'FocusApp/Core/Models.swift'
shared_store = 'FocusApp/Core/SharedStore.swift'
time_policy = 'FocusApp/Core/TimePolicy.swift'
shield_policy = 'FocusApp/Core/ShieldPolicy.swift'

app = project.new_target(:application, 'FocusApp', :ios, '18.0')
app.product_name = 'LockIn'
configure(app, bundle_id: 'com.dash1971.focusapp', plist: 'FocusApp/Resources/Info.plist', entitlements: 'FocusApp/FocusApp.entitlements')
app.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'LockIn'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'LockIn'
  config.build_settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.productivity'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
end

app_sources = Dir.glob(File.join(root, 'FocusApp/**/*.swift')).map { |p| p.delete_prefix("#{root}/") }.sort
add_sources(project, app, app_sources)
add_resources(project, app, ['FocusApp/Resources/Assets.xcassets', 'FocusApp/Resources/PrivacyInfo.xcprivacy'])
%w[FamilyControls.framework ManagedSettings.framework DeviceActivity.framework UserNotifications.framework AudioToolbox.framework WidgetKit.framework].each { |f| add_framework(project, app, f) }

extensions = [
  {
    name: 'DeviceActivityMonitorExtension',
    directory: 'Extensions/DeviceActivityMonitor',
    bundle: 'com.dash1971.focusapp.deviceactivity',
    sources: [models, shared_store, time_policy, shield_policy, 'Extensions/DeviceActivityMonitor/DeviceActivityMonitorExtension.swift'],
    frameworks: %w[DeviceActivity.framework ManagedSettings.framework FamilyControls.framework]
  },
  {
    name: 'ShieldConfigurationExtension',
    directory: 'Extensions/ShieldConfiguration',
    bundle: 'com.dash1971.focusapp.shieldconfiguration',
    sources: ['Extensions/ShieldConfiguration/ShieldConfigurationExtension.swift'],
    frameworks: %w[ManagedSettings.framework ManagedSettingsUI.framework FamilyControls.framework DeviceActivity.framework UIKit.framework]
  },
  {
    name: 'ShieldActionExtension',
    directory: 'Extensions/ShieldAction',
    bundle: 'com.dash1971.focusapp.shieldaction',
    sources: ['Extensions/ShieldAction/ShieldActionExtension.swift'],
    frameworks: %w[ManagedSettings.framework]
  }
]

embed_phase = app.new_copy_files_build_phase('Embed App Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins

extensions.each do |spec|
  target = project.new_target(:app_extension, spec[:name], :ios, '18.0')
  configure(
    target,
    bundle_id: spec[:bundle],
    plist: "#{spec[:directory]}/Info.plist",
    entitlements: "#{spec[:directory]}/#{spec[:name].sub('Extension', '')}.entitlements"
  )
  target.build_configurations.each do |config|
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  end
  add_sources(project, target, spec[:sources])
  spec[:frameworks].each { |f| add_framework(project, target, f) }
  app.add_dependency(target)
  build_file = embed_phase.add_file_reference(target.product_reference, true)
  build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy CodeSignOnCopy] }
end

widget = project.new_target(:app_extension, 'LockInWidgetsExtension', :ios, '18.0')
configure(
  widget,
  bundle_id: 'com.dash1971.focusapp.widgets',
  plist: 'Extensions/LockInWidgets/Info.plist',
  entitlements: 'Extensions/LockInWidgets/LockInWidgets.entitlements'
)
widget.build_configurations.each do |config|
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = 'LockInWidgets'
end
add_sources(project, widget, [models, shared_store, time_policy, 'Extensions/LockInWidgets/LockInWidgets.swift'])
%w[WidgetKit.framework SwiftUI.framework FamilyControls.framework DeviceActivity.framework].each { |f| add_framework(project, widget, f) }
app.add_dependency(widget)
widget_build_file = embed_phase.add_file_reference(widget.product_reference, true)
widget_build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy CodeSignOnCopy] }

tests = project.new_target(:unit_test_bundle, 'FocusAppTests', :ios, '18.0')
configure(tests, bundle_id: 'com.dash1971.focusapp.tests')
tests.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/LockIn.app/LockIn'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
test_sources = Dir.glob(File.join(root, 'FocusAppTests/**/*.swift')).map { |p| p.delete_prefix("#{root}/") }.sort
add_sources(project, tests, test_sources)
add_framework(project, tests, 'XCTest.framework')
tests.add_dependency(app)

project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

project.recreate_user_schemes
project.save
shared_schemes = File.join(project_path, 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(shared_schemes)
%w[FocusApp FocusAppTests].each do |name|
  scheme = Dir.glob(File.join(project_path, 'xcuserdata', '*', 'xcschemes', "#{name}.xcscheme")).first
  FileUtils.cp(scheme, shared_schemes) if scheme
end
puts "Generated #{project_path}"
