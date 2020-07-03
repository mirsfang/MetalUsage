//
//  ViewController.m
//  triangle
//
//  Created by mirsfang on 2020/6/17.
//  Copyright © 2020 mirsfang. All rights reserved.
//
@import MetalKit;
#import "ViewController.h"
#import "ShaderType.h"

@interface ViewController () <MTKViewDelegate>

@property(nonatomic,strong)MTKView * mtkView;

@property(nonatomic,strong) id <MTLRenderPipelineState> pipelineState;
@property(nonatomic,strong) id <MTLDepthStencilState> depthState;
@property(nonatomic,strong) id <MTLCommandQueue> commandQueue;
@property(nonatomic,strong) id <MTLBuffer> vertexBuffer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds device:MTLCreateSystemDefaultDevice()];
    self.view = self.mtkView;
    self.mtkView.delegate = self;
    
    self.mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    //每个颜色的采样个数，正常情况每个像素采样一个，如果需要实现MSAA抗锯齿，需要设置的更多
    self.mtkView.sampleCount = 1;
    
    [self metalInit];
    [self loadAssets];
}

-(void) metalInit{
    id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
    
    /* 初始化当前的一些信息  入口函数，颜色和深度信息的描述对象  MTLRenderPipelineDescriptor */
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Pipeline";
    pipelineStateDescriptor.sampleCount = self.mtkView.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat  = self.mtkView.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;
    
    /* 根据描述信息创建渲染当前渲染状态 MTLRenderPipelineState */
    NSError *error = NULL;
    _pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if(!_pipelineState){
        NSLog(@"Failed to created pipeline state,error : %@",error);
    }
    
    /* 设置深度测试描述  MTLDepthStencilDescriptor */
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
        
    /* 生成深度测试状态 MTLDepthStencilState */
    _depthState = [self.mtkView.device newDepthStencilStateWithDescriptor:depthStateDesc];
    _commandQueue = [self.mtkView.device newCommandQueue];
}


-(void) loadAssets{
    /* 创建顶点信息与顶点Buffer */
    static const Vertex vert[] = {
       {{0,1.0}},
         {{1.0,-1.0}},
        {{-1.0,-1.0}},
    };
    /* 生成顶点Buffer MTLBuffer*/
    _vertexBuffer = [self.mtkView.device newBufferWithBytes:vert length:sizeof(vert) options:MTLResourceStorageModeShared];
}


- (void)drawInMTKView:(MTKView *)view{
    /* 通过commandQueue 生成commandBuffer  MTLCommandBuffer */
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"commandBuffer";
    MTLRenderPassDescriptor *renderPassDescriptor = self.mtkView.currentRenderPassDescriptor;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
    if(renderPassDescriptor != nil)
    {
        /* 通过渲染指令描述，创建Encoder MTLRenderCommandEncoder  */
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"RenderEncoder";
        /* 设置渲染指令 */
        [renderEncoder pushDebugGroup:@"Draw Triangle"];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setDepthStencilState:_depthState];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        //设置绘制的方式和顶点
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [renderEncoder popDebugGroup];
        
        /* 渲染结束 */
        [renderEncoder endEncoding];
        /* 设置显示对象 */
        [commandBuffer presentDrawable:self.mtkView.currentDrawable];
    }
    /*提交commandBuffer到commandQueue*/
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
    
}

@end
