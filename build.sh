
PROJECT="ReCaptcha-Carthage.xcodeproj"
SCHEME="ReCaptcha"
FRAMEWORK_NAME="ReCaptcha"
IPHONEOS_ARCHIVE_PATH="./build/${FRAMEWORK_NAME}-iphoneos.xcarchive"
IPHONESIMULATOR_ARCHIVE_PATH="./build/${FRAMEWORK_NAME}-iphonesimulator.xcarchive"
OUTPUT_PATH="./build/${FRAMEWORK_NAME}.xcframework"
rm -rf ${OUTPUT_PATH}
set -o pipefail

# Device slice.
xcodebuild clean archive \
    -project ${PROJECT} \
    -scheme ${SCHEME} \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -archivePath ${IPHONEOS_ARCHIVE_PATH} \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES | xcpretty
# Simulator slice.
xcodebuild clean archive \
    -project ${PROJECT} \
    -scheme ${SCHEME} \
    -configuration Release \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -archivePath ${IPHONESIMULATOR_ARCHIVE_PATH} \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES | xcpretty
function GetUUID() {
    # dwarfdump output:
    # UUID: FFFFFFF-AAAAA-BBBB-CCCC-DDDDDDDDDD (arm64) PATH_TO_ARCHIVE/FRAMEWORK.framework-ios-arm64.xcarchive/Products/Library/Frameworks/FRAMEWORK.framework/FRAMEWORK
    local arch=$1
    local binary=$2
    local dwarfdump_result=$(dwarfdump -u ${binary})
    local regex=".*UUID: (.*) \(($arch)\)"
    if [[ $dwarfdump_result =~ $regex ]]; then
        # This will fail if dwarfdump returns more than one result (ex. supporting armv7 as well)
        local result_uuid="${BASH_REMATCH[1]}"
        local result_arch="${BASH_REMATCH[2]}"
         
        if [ "$result_arch" == "$arch" ]; then
            echo $result_uuid
        fi
    fi
}
# First, find UUID for BCSymbolMaps of our binary, because these are randomly generated. The dSYM path is always the same so that one is manually added
# Simulator-targeted archives don't generate BCSymbolMap files, so this is only needed for iphone target
BCSYMBOLMAP_UUID_ARM64=$(GetUUID "arm64" "${IPHONEOS_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}")
BCSYMBOLMAP_UUID_ARMV7=$(GetUUID "armv7" "${IPHONEOS_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}")
# Create XCFramework
xcodebuild -create-xcframework \
    -framework "${IPHONEOS_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
    -debug-symbols "${PWD}/${IPHONEOS_ARCHIVE_PATH}/dSYMs/${FRAMEWORK_NAME}.framework.dSYM" \
    -debug-symbols "${PWD}/${IPHONEOS_ARCHIVE_PATH}/BCSymbolMaps/${BCSYMBOLMAP_UUID_ARM64}.bcsymbolmap" \
    -debug-symbols "${PWD}/${IPHONEOS_ARCHIVE_PATH}/BCSymbolMaps/${BCSYMBOLMAP_UUID_ARMV7}.bcsymbolmap" \
    -framework "${IPHONESIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
    -debug-symbols "${PWD}/${IPHONESIMULATOR_ARCHIVE_PATH}/dSYMs/${FRAMEWORK_NAME}.framework.dSYM" \
    -output ${OUTPUT_PATH}
# Cleanup
rm -rf "${IPHONEOS_ARCHIVE_PATH}"
rm -rf "${IPHONESIMULATOR_ARCHIVE_PATH}"