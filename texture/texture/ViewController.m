//
//  ViewController.m
//  texture
//
//  Created by mirsfang on 2020/6/17.
//  Copyright © 2020 mirsfang. All rights reserved.
//

@import MetalKit;
#import "ViewController.h"
#import "ShaderType.h"

@interface ViewController ()<MTKViewDelegate>

@property(nonatomic,strong)MTKView * mtkView;
@property(nonatomic,strong)id<MTLCommandQueue> commandQueue;
@property(nonatomic,strong)id<MTLRenderPipelineState> pipelineState;
@property(nonatomic,strong)id<MTLDepthStencilState> depthState;

@property(nonatomic,strong)id<MTLBuffer> vertexBuffer;
@property(nonatomic,assign)NSUInteger numVertices;

@property(nonatomic,strong)id<MTLTexture> texture;
@property(nonatomic,assign)vector_int2 viewPortSize;

@property(nonatomic,assign) matrix_float4x4 mvpMatrix;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _mtkView = [[MTKView alloc] initWithFrame:self.view.bounds device:MTLCreateSystemDefaultDevice()];
    _mtkView.delegate = self;
    _viewPortSize = (vector_int2){self.mtkView.drawableSize.width, self.mtkView.drawableSize.height};
    self.view = _mtkView;

    _mvpMatrix = (matrix_float4x4){ {
        { 1, 0, 0, 0.5},     // Each line here provides column data.
        { 0, 1, 0, 0 },
        { 0, 0, 1, 0 },
        { 0, 0, 0, 1 }}
    };
    
    [self metalInit];
    [self loadAssets];
    [self loadTexture];
    
}


-(void) metalInit{
    id<MTLLibrary> defaultLibrary = [_mtkView.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor * pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Piepline";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat =_mtkView.colorPixelFormat;
    
    NSError * error = NULL;
    _pipelineState = [_mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if(!_pipelineState){
        NSLog(@"Failed to created pipeline state,error : %@",error);
    }
    
    /*生成深度模板测试状态类*/
    MTLDepthStencilDescriptor * depthStateDesc = [[MTLDepthStencilDescriptor alloc]init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    
    _depthState = [_mtkView.device newDepthStencilStateWithDescriptor:depthStateDesc];
    _commandQueue = [_mtkView.device newCommandQueue];
}

-(void) loadAssets{
    static const Vertex ver[] = {
        // 顶点坐标，分别是x、y、z、w；    纹理坐标，x、y；
        { {  1, -0.35, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -1, -0.35, 0.0, 1.0 },  { 0.f, 1.f } },
        { { -1,  0.35, 0.0, 1.0 },  { 0.f, 0.f } },
                 
        { {  1, -0.35, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -1,  0.35, 0.0, 1.0 },  { 0.f, 0.f } },
        { {  1,  0.35, 0.0, 1.0 },  { 1.f, 0.f } },
    };
    
    _vertexBuffer = [_mtkView.device newBufferWithBytes:ver length:sizeof(ver) options:MTLResourceStorageModeShared];
    _numVertices = sizeof(ver)/sizeof(Vertex); //获取顶点个数
}

-(void) loadTexture{
    UIImage *image = [UIImage imageNamed:@"test"];
    MTLTextureDescriptor * textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.width = image.size.width;
    textureDescriptor.height = image.size.height;
    _texture = [_mtkView.device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = {{0,0,0},{image.size.width,image.size.height,1}};//纹理上传的范围
    Byte *imageBytes = [self loadImage:image];
    if(imageBytes)
    {
        [self.texture replaceRegion:region mipmapLevel:0 withBytes:imageBytes bytesPerRow:4 * image.size.width];
        free(imageBytes);
        imageBytes = NULL;
    }
}

-(Byte *) loadImage:(UIImage *) image{
    CGImageRef spriteImage = image.CGImage;
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    Byte * spriteDate = (Byte *)calloc(width * height * 4, sizeof(Byte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteDate, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    CGContextRelease(spriteContext);
    
    return spriteDate;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
    self.viewPortSize = (vector_int2){size.width,size.height};
}

- (void)drawInMTKView:(MTKView *)view{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor * renderPassDescriptor = view.currentRenderPassDescriptor;
    if(renderPassDescriptor){
        renderPassDescriptor.colorAttachments[0].clearColor =  MTLClearColorMake(0.0, 0.5, 0.5, 1.0f);
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder setViewport: (MTLViewport){0.0,0.0,_viewPortSize.x,_viewPortSize.y}];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder  setVertexBytes:&_mvpMatrix length:sizeof(_mvpMatrix) atIndex:1];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_texture atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_numVertices];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:_mtkView.currentDrawable];
    }
    [commandBuffer commit];
}

@end
