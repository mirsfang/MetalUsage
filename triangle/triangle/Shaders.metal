//
//  Shaders.metal
//  triangle
//
//  Created by mirsfang on 2020/6/17.
//  Copyright © 2020 mirsfang. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

#import "ShaderType.h"

using namespace metal;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ColorInput;

vertex ColorInput vertexShader(constant Vertex *vertexArr [[buffer(0)]],
                               uint vid [[vertex_id]]
                               ){
    
    ColorInput out;
    float4 position = vector_float4(vertexArr[vid].pos,0,1.0);
    out.position = position;
    return out;
}


fragment float4 fragmentShader(ColorInput in [[stage_in]]){
    return float4(1,0,0,0);
}
