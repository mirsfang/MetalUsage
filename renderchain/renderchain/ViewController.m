//
//  ViewController.m
//  renderchain
//
//  Created by mirsfang on 2020/6/18.
//  Copyright © 2020 mirsfang. All rights reserved.
//
@import MetalKit;
#import "ViewController.h"
#import "ShaderType.h"
@interface ViewController () <MTKViewDelegate>

@property(nonatomic,strong) MTKView * mtkview;
@property(nonatomic,assign)vector_uint2 viewportSize;
@property(nonatomic,assign)vector_uint2 imageSize;
@property(nonatomic,strong)id<MTLCommandQueue> commandQueue;

@property(nonatomic,strong)id<MTLRenderPipelineState> pipelineStateBase;
@property(nonatomic,strong)id<MTLRenderPipelineState> pipelineState;
@property(nonatomic,strong)MTLRenderPassDescriptor * renderPassDescriptor;
@property(nonatomic,strong)MTLRenderPassDescriptor * outputRenderPassDescriptor;

@property(nonatomic,strong)id<MTLTexture> inputTexture;
@property(nonatomic,strong)id<MTLTexture> imageTexture;
@property(nonatomic,strong)id<MTLBuffer> vertices;
@property(nonatomic,assign) NSUInteger numVertices;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _mtkview = [[MTKView alloc] initWithFrame:self.view.bounds device:MTLCreateSystemDefaultDevice()];
    _mtkview.delegate = self;
    self.view  = self.mtkview;
    self.viewportSize = (vector_uint2){self.mtkview.drawableSize.width,self.mtkview.drawableSize.height};
  
    [self customInit];
}

-(void)customInit {
    [self initPipeline];
}

-(void) initPipeline{
    id<MTLLibrary> defaultLibrary = [_mtkview.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
    id<MTLFunction> fragmentBaseFunction = [defaultLibrary newFunctionWithName:@"fragmentShaderBase"];
    
    MTLRenderPipelineDescriptor * pipelineDescBase = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescBase.vertexFunction = vertexFunction;
    pipelineDescBase.fragmentFunction = fragmentBaseFunction;
    pipelineDescBase.colorAttachments[0].pixelFormat = _mtkview.colorPixelFormat;
    
    NSError * error;
    _pipelineStateBase = [_mtkview.device newRenderPipelineStateWithDescriptor:pipelineDescBase error:&error];
    if(error){
           NSLog(@"[Error] Failed to create PipelineState %@",error);
    }
    
    MTLRenderPipelineDescriptor * pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexFunction = vertexFunction;
    pipelineDesc.fragmentFunction = fragmentFunction;
    pipelineDesc.colorAttachments[0].pixelFormat = _mtkview.colorPixelFormat;
    
    _pipelineState = [_mtkview.device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
    if(error){
        NSLog(@"[Error] Failed to create PipelineState %@s",error);
    }
    
    UIImage * image = [UIImage imageNamed:@"test"];
    _imageSize = (vector_uint2){image.size.width,image.size.height};
    
    /* 图像Texture */
    MTLTextureDescriptor  * imageDesc = [MTLTextureDescriptor new];
    imageDesc.pixelFormat = _mtkview.colorPixelFormat;
    imageDesc.width = image.size.width;
    imageDesc.height = image.size.height;
    _imageTexture = [_mtkview.device newTextureWithDescriptor:imageDesc];
    
    MTLRegion region = {{0,0,0},{image.size.width,image.size.height,1}};
    Byte * imageBytes = [self loadImage:image];
    if(imageBytes){
        /* 上传图像数据到texture */
        [self.imageTexture replaceRegion:region
                          mipmapLevel:0
                            withBytes:imageBytes
                          bytesPerRow:4*image.size.width];
        free(imageBytes);
        imageBytes = NULL;
    }
    
    /* 第一个Texture */
    MTLTextureDescriptor * inputDesc = [MTLTextureDescriptor new];
    inputDesc.pixelFormat = MTLPixelFormatBGRA8Unorm;
    inputDesc.width = _imageSize.x;
    inputDesc.height = _imageSize.y;
    inputDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    _inputTexture = [_mtkview.device newTextureWithDescriptor:inputDesc];
    
    _renderPassDescriptor = [MTLRenderPassDescriptor new];
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0.5, 1);
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    _renderPassDescriptor.colorAttachments[0].texture = _inputTexture;
    
    _outputRenderPassDescriptor = _mtkview.currentRenderPassDescriptor;
    _outputRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);

    _commandQueue = [_mtkview.device newCommandQueue];
    
    
    static const Vertex quadVertices[] =
         {   // 顶点坐标，分别是x、y、z、w；    纹理坐标，x、y；
             { {  1, -1, 0.0, 1.0 },  { 1.f, 1.f } },
             { { -1, -1, 0.0, 1.0 },  { 0.f, 1.f } },
             { { -1,  1, 0.0, 1.0 },  { 0.f, 0.f } },
             
             { {  1, -1, 0.0, 1.0 },  { 1.f, 1.f } },
             { { -1,  1, 0.0, 1.0 },  { 0.f, 0.f } },
             { {  1,  1, 0.0, 1.0 },  { 1.f, 0.f } },
         };
       
       /* 新建顶点缓存 */
       self.vertices = [self.mtkview.device newBufferWithBytes:quadVertices
                                                       length:sizeof(quadVertices)
                                                       options:MTLResourceStorageModeShared]; // 创建顶点缓存
     self.numVertices = sizeof(quadVertices)/sizeof(Vertex);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
    self.viewportSize = (vector_uint2){size.width,size.height};
}

- (void)drawInMTKView:(MTKView *)view{
    id<MTLCommandBuffer> commandBuffer =[_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    renderEncoder.label =@"Input Texture";
    [renderEncoder setViewport:(MTLViewport){0,0,self.imageSize.x,self.imageSize.y,-1.0,1.0}];
    [renderEncoder setRenderPipelineState:_pipelineStateBase];
    [renderEncoder setVertexBuffer:self.vertices offset:0 atIndex:0];
    [renderEncoder setFragmentTexture:self.imageTexture atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.numVertices];
    [renderEncoder endEncoding];
    
    MTLRenderPassDescriptor * renderPass = self.mtkview.currentRenderPassDescriptor;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
    id<MTLRenderCommandEncoder> renderEncoder2 = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    renderEncoder2.label = @"Output Texture";
    [renderEncoder2 setViewport:(MTLViewport){0,0,_viewportSize.x,_viewportSize.y,-1.0,1.0}];
    [renderEncoder2 setRenderPipelineState:_pipelineState];
    [renderEncoder2 setVertexBuffer:self.vertices offset:0 atIndex:0];
    [renderEncoder2 setFragmentTexture:_inputTexture atIndex:0];
    [renderEncoder2 drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.numVertices];
    [renderEncoder2 endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    
    [commandBuffer commit];
}

-(Byte *)loadImage:(UIImage *)image{
    CGImageRef spriteImage = image.CGImage;
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height= CGImageGetHeight(spriteImage);
    
    Byte * spriteData = (Byte *)calloc(width * height * 4, sizeof(Byte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8,
                                                       width * 4,
                                                       CGImageGetColorSpace(spriteImage),
                                                       kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    return spriteData;
}

@end
