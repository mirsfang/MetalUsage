//
//  Shader.metal
//  renderchain
//
//  Created by mirsfang on 2020/6/19.
//  Copyright © 2020 mirsfang. All rights reserved.
//

#include <metal_stdlib>
#import "ShaderType.h"
using namespace metal;


typedef struct
{
    float4 vertextPosition [[position]]; //position 修饰符表示是顶点
    float2 textureCoord; //纹理坐标
}ColorInOut;

vertex ColorInOut vertexShader(uint vertexId [[vertex_id]],
                               constant Vertex * vertexArray [[ buffer(0) ]]
                               ){
    ColorInOut out;
    out.vertextPosition = vertexArray[vertexId].pos;
    out.textureCoord = vertexArray[vertexId].textureCoordnate;
    return out;
}

fragment float4 fragmentShader(ColorInOut input [[stage_in]],
                               texture2d<half> colorTexture [[ textur(0) ]])
{
    //设置采样
    constexpr sampler textureSampler(mag_filter::linear,min_filter::linear);
    
    //获取到纹理对应的颜色
    half4 colorSample = colorTexture.sample(textureSampler, input.textureCoord);
    
    return float4(colorSample.r,colorSample.r,colorSample.r,1);
}


fragment float4 fragmentShaderBase(ColorInOut input [[stage_in]],
texture2d<half> colorTexture [[ textur(0) ]]){
    //设置采样
       constexpr sampler textureSampler(mag_filter::linear,min_filter::linear);
       //获取到纹理对应的颜色
       half4 colorSample = colorTexture.sample(textureSampler, input.textureCoord);
    
      return float4(colorSample);
}
