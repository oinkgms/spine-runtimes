#include "spine_flutter.h"
#include <spine/spine.h>
#include <spine/Version.h>

using namespace spine;

FFI_PLUGIN_EXPORT int32_t spine_major_version() {
    return SPINE_MAJOR_VERSION;
}

FFI_PLUGIN_EXPORT int32_t spine_minor_version() {
    return SPINE_MINOR_VERSION;
}

FFI_PLUGIN_EXPORT spine_atlas* spine_atlas_load(const char *atlasData) {
    int length = strlen(atlasData);
    auto atlas = new Atlas(atlasData, length, "", (TextureLoader*)nullptr, false);
    spine_atlas *result = SpineExtension::calloc<spine_atlas>(1, __FILE__, __LINE__);
    result->atlas = atlas;
    result->numImagePaths = atlas->getPages().size();
    result->imagePaths = SpineExtension::calloc<char *>(result->numImagePaths, __FILE__, __LINE__);
    for (int i = 0; i < result->numImagePaths; i++) {
        result->imagePaths[i] = strdup(atlas->getPages()[i]->texturePath.buffer());
    }
    return result;
}

FFI_PLUGIN_EXPORT void spine_atlas_dispose(spine_atlas *atlas) {
    if (!atlas) return;
    if (atlas->atlas) delete (Atlas*)atlas->atlas;
    if (atlas->error) free(atlas->error);
    for (int i = 0; i < atlas->numImagePaths; i++) {
        free(atlas->imagePaths[i]);
    }
    SpineExtension::free(atlas, __FILE__, __LINE__);
}

spine::SpineExtension *spine::getDefaultExtension() {
   return new spine::DefaultSpineExtension();
}