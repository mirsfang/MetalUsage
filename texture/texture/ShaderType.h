//
//  ShaderTpye.h
//  texture
//
//  Created by mirsfang on 2020/6/17.
//  Copyright © 2020 mirsfang. All rights reserved.
//

#ifndef ShaderType_h
#define ShaderType_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef struct {
    vector_float4 pos;
    vector_float2 textureCoordnate;
} Vertex;

#endif /* ShaderType_h */
