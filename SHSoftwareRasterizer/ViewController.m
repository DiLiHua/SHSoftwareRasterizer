//
//  ViewController.m
//  SHSoftwareRasterizer
//
//  Created by 7heaven on 16/5/7.
//  Copyright © 2016年 7heaven. All rights reserved.
//

#import "ViewController.h"
#import "SHSoftwareCanvas.h"
#import "Matrix44.hpp"
#import "BasicDraw.hpp"
#import "BoxObject.h"
#import "Object3DEntity.h"
#import <sys/time.h>
#import "IDevice.h"
#import "Texture.hpp"
#import "FakeLight.hpp"
#import "SimpleDiffuseLight.hpp"
#import "Transform.hpp"

#define N 750.0f

#define compareByte(a, b) [a.description isEqualToString:b]

@implementation ViewController{
    sh::IDevice *_renderDevice;
    NSTimer *timer;
    
    float angle;
    
    sh::Transform *_transform;
    
    sh::Transform *_worldTransform;
    sh::Transform *_projectionTransform;
    
    Object3DEntity *_box;
    
    int _intx;
    int _inty;
    
    int _tx;
    int _ty;
    
    CGPoint _dragPoint;
    CGPoint centerPoint;
    CGFloat _previousRadianX;
    CGFloat _previousRadianY;
    
    SHRect dirtyRect;
    
    sh::Texture *texture;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    SHSoftwareCanvas *canvas = [[SHSoftwareCanvas alloc] initWithBackgroundColor:SHColorMake(0xFF0099CC)];
    canvas.frame = self.view.bounds;
    _renderDevice = [canvas getNativePtr];
    
    [self.view addSubview:canvas];
    
    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect |
                                     NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);
    
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.view.bounds
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];
    
    [self.view addTrackingArea:area];
    
    _transform = new sh::Transform();
    
    float scaleFactor = 1.0F;
    _worldTransform = sh::Transform::scale(SHVector3DMake(scaleFactor, scaleFactor, scaleFactor, 1));
    
    _projectionTransform = sh::Transform::perspective(N);
    
    _box = [[BoxObject alloc] initWithLength:150];
    
    centerPoint = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    dirtyRect = SHRectMake(0, 0, 0, 0);
    
    [self.fpsLabel removeFromSuperview];
    [self.view addSubview:self.fpsLabel];
    
    [self.fileButton removeFromSuperview];
    [self.view addSubview:self.fileButton];
    
    texture = [self readTextureFromImage:[NSImage imageNamed:@"uv_spaceship_revert"]];
}

- (sh::Texture *) readTextureFromImage:(NSImage *) image{
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    imageRep = [imageRep bitmapImageRepByConvertingToColorSpace:[NSColorSpace deviceRGBColorSpace] renderingIntent:NSColorRenderingIntentDefault];
    
    int width = (int) [imageRep pixelsWide];
    int height = (int) [imageRep pixelsHigh];
    
    SHColor *pixels = (SHColor *) malloc(width * height * sizeof(SHColor));
    
    for(int y = 0; y < height; y++){
        for(int x = 0; x < width; x++){
            NSColor *c = [imageRep colorAtX:x y:y];
            
            pixels[y * width + x] = (SHColor){0xFF, static_cast<unsigned char>(c.redComponent * 255), static_cast<unsigned char>(c.greenComponent * 255), static_cast<unsigned char>(c.blueComponent * 255)};
        }
    }
    
    return new sh::Texture(pixels, width, height);
    
}


- (void) rotateX:(float) x y:(float) y{
    
    sh::Transform *rotate = sh::Transform::rotate(x, y, 0);
    
    *_transform *= *rotate;
    *_transform *= *_worldTransform;
    
}

- (void) mouseDown:(NSEvent *)theEvent{
    CGPoint location = theEvent.locationInWindow;
    
    if (isnan(_dragPoint.x) || isnan(_dragPoint.y)) _dragPoint = CGPointMake(0, 0);
    if (!_box) _box = [[BoxObject alloc] initWithLength:150];
    
    _intx = location.x;
    _inty = location.y;
}

////github项目miniPC给出的透视投影矩阵
//- (sh::Matrix44 *) getPerspectiveMatrixWithFovy:(float) fovy aspect:(float) aspect zn:(float) zn zf:(float) zf{
//    float fax = 1.0F / (float) tan(fovy * 0.5F * (M_PI / 180));
//    
//    sh::Matrix44 *projectMat = new sh::Matrix44((float)(fax),            0,                    0, 0,
//                                                           0, (float)(fax),                    0, 0,
//                                                           0,            0,       zf / (zf - zn), 1,
//                                                           0,            0, -zn * zf / (zf - zn), 0);
//    
//    return projectMat;
//}

- (void) mouseDragged:(NSEvent *)theEvent{
    timeval time;
    gettimeofday(&time, NULL);
    long previousTime = (time.tv_sec * 1000) + (time.tv_usec / 1000);
    
    CGPoint location = theEvent.locationInWindow;
    
    _tx = location.x - _intx;
    _ty = location.y - _inty;
    
    _dragPoint = CGPointMake(_dragPoint.x + (_tx - _dragPoint.x) * 0.01, _dragPoint.y + (_ty - _dragPoint.y) * 0.01);
    
//    [canvas flushWithDirtyRect:dirtyRect color:SHColorMake(0x0)];
//    dirtyRect = SHRectMake(0, 0, 0, 0);
//    [canvas flushWithColor:SHColorMake(0xFF0099CC)];
    _renderDevice->flush(SHColorMake(0xFF0099CC));
    
    //矩阵还原
    _transform->m->toIdentity();
    
    (*_transform->m)[2][3] = 400;
    
    //矩阵旋转
    [self rotateX:(_tx - centerPoint.x) / 200 + _previousRadianX y:(_ty - centerPoint.y) / 200 + _previousRadianY];
    
    for(int i = 0; i < _box.triangleArray.count; i++){
        //获取三角形
        SHSimpleTri tri = getSimpleTri(_box.triangleArray[i]);
        
        //获取三角形对应的顶点
        SHVector3D a = getVector3D(_box.vectorArray[tri.a]);
        SHVector3D b = getVector3D(_box.vectorArray[tri.b]);
        SHVector3D c = getVector3D(_box.vectorArray[tri.c]);
        
        //获取三角形顶点的uv坐标
        SHPointF auv = getUV(_box.uvMapArray[tri.a]);
        SHPointF buv = getUV(_box.uvMapArray[tri.b]);
        SHPointF cuv = getUV(_box.uvMapArray[tri.c]);
        
        //世界坐标变换
        a = *_transform * a;
        b = *_transform * b;
        c = *_transform * c;
        
        
        //二维透视投影
        SHVector3D a2D = *_projectionTransform * a;
        SHVector3D b2D = *_projectionTransform * b;
        SHVector3D c2D = *_projectionTransform * c;
        
        //获取二维屏幕坐标
        SHPoint pa = SHPointMake(a2D.x / a2D.w + centerPoint.x, a2D.y / a2D.w + centerPoint.y);
        SHPoint pb = SHPointMake(b2D.x / b2D.w + centerPoint.x, b2D.y / b2D.w + centerPoint.y);
        SHPoint pc = SHPointMake(c2D.x / c2D.w + centerPoint.x, c2D.y / c2D.w + centerPoint.y);
        
        //检查dirtyRect
//        [self checkDirty:pa];
//        [self checkDirty:pb];
//        [self checkDirty:pc];
        
        //二维向量叉乘，用此方法判断三角形是顺时针还是逆时针，如果逆时针则跳过
        float s = [self crossProductWith:(SHPoint){pb.x - pa.x, pb.y - pa.y}
                                    p1:(SHPoint){pc.x - pa.x, pc.y - pa.y}];
        
        if(s > 0) continue;
        
        //三维向量取模，用来计算光线值
        float m = [self crossProWithV0:(SHVector3D){b.x - a.x, b.y - a.y, b.z - a.z, 1} v1:(SHVector3D){c.x - a.x, c.y - a.y, c.z - a.z, 1} center:centerPoint];
        
        if(m > 1) m = 1.0F;
        if(m < 0) m = 0.0F;
        
        //根据m来计算的光线，这个类取名容易引起困惑，实际上应该取名Material再引入场景内的灯光来计算，待修改
        sh::ILight *light = new sh::FakeLight(m);
        
        sh::Vertex3D *va = new sh::Vertex3D();
        va->pos = a;
        va->screenPos = pa;
        va->u = auv.x;
        va->v = auv.y;
        
        sh::Vertex3D *vb = new sh::Vertex3D();
        vb->pos = b;
        vb->screenPos = pb;
        vb->u = buv.x;
        vb->v = buv.y;
        
        sh::Vertex3D *vc = new sh::Vertex3D();
        vc->pos = c;
        vc->screenPos = pc;
        vc->u = cuv.x;
        vc->v = cuv.y;
        
        
        //扫描线绘制三角形
        sh::BasicDraw::drawPerspTriangle(*_renderDevice, va, vb, vc, *texture, *light);
        
    }

    _renderDevice->update();
    
    timeval aftertime;
    gettimeofday(&aftertime, NULL);
    long currentTime = (aftertime.tv_sec * 1000) + (aftertime.tv_usec / 1000);
    long gap = currentTime - previousTime;
    int fps = 1000 / (gap + 1);
    
    [self.fpsLabel setStringValue:[NSString stringWithFormat:@"%ldms/F", gap]];
    
}

- (void) checkDirty:(SHPoint) p{
    if(p.x < dirtyRect.x) dirtyRect.x = p.x - 1;
    if(p.y < dirtyRect.y) dirtyRect.y = p.y - 1;
    if(p.x > dirtyRect.x + dirtyRect.w) dirtyRect.w = p.x - dirtyRect.x + 2;
    if(p.y > dirtyRect.y + dirtyRect.h) dirtyRect.h = p.y - dirtyRect.y + 2;
}

- (float) crossProductWith:(SHPoint) p0 p1:(SHPoint) p1{
    float s = p0.x * p1.y - p1.x * p0.y;
    
    return s;
}

- (float)crossProWithV0:(SHVector3D)v0 v1:(SHVector3D)v1 center:(CGPoint)cPoint {
    CGFloat t_x = v0.y * v1.z - v0.z * v1.y;
    CGFloat t_y = v0.z * v1.x - v0.x * v1.z;
    CGFloat t_z = v0.x * v1.y - v0.y * v1.x;
    
    CGFloat m = sqrt(t_x * t_x + t_y * t_y + t_z * t_z);
    t_x -= m * (cPoint.x - cPoint.x) / cPoint.x;
    t_y -= m * (cPoint.y - cPoint.x) / cPoint.x;
    //向量单位化
    t_x /= m;
    t_y /= m;
    //不开方,以减少运算量
    return t_x * t_x + t_y * t_y;
}

- (void)mouseUp:(NSEvent *)theEvent {
    CGPoint location = theEvent.locationInWindow;
    
    _previousRadianX = (_tx - centerPoint.x) / 200 + _previousRadianX;
    _previousRadianY = (_ty - centerPoint.y) / 200 + _previousRadianY;
}


//解析3DS文件，仅实现了三角面片，顶点坐标的解析
- (Object3DEntity *)parse3DSFileWithPath:(NSURL *)path {

    NSData *fileData = [NSData dataWithContentsOfURL:path];
    if (fileData) {
        Object3DEntity *object3D = [[Object3DEntity alloc] init];
        
        NSUInteger totalBytesCount = [fileData length];
        
        NSInteger index = 0;
        
        NSData *byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
        
        index += 2;
        
        NSData *chunkLength = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
        
        index += 4;
        
        NSInteger totalLength = 0;
        while (index < totalBytesCount) {
//            if (self.delegate && [self.delegate respondsToSelector:@selector(fileParser:parseProgress:)]) {
//                [self.delegate fileParser:self parseProgress:totalLength > 0 ? (float)index / (float)totalLength : 0];
//            }
            
            int length;
            
            [chunkLength getBytes:&length length:sizeof(length)];
            
            if (compareByte(byteData, @"<4d4d>")) {
                [chunkLength getBytes:&totalLength length:sizeof(totalLength)];
                // file header
            } else if (compareByte(byteData, @"<3d3d>")) {
            } else if (compareByte(byteData, @"<0041>")) {
            } else if (compareByte(byteData, @"<0040>")) {
                byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:1];
                index += 1;
                
                char size;
                
                [byteData getBytes:&size length:sizeof(size)];
                while (size != 0) {
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:1];
                    index += 1;
                    
//                    if (self.delegate && [self.delegate respondsToSelector:@selector(fileParser:parseProgress:)]) {
//                        [self.delegate fileParser:self
//                                    parseProgress:totalLength > 0 ? (float)index / (float)totalLength : 0];
//                    }
                    
                    [byteData getBytes:&size length:sizeof(size)];
                }
                
            } else if (compareByte(byteData, @"<1041>")) {
                byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
                
                index += 2;
                short size;
                [byteData getBytes:&size length:sizeof(size)];
                for (int i = 0; i < size; i++) {
//                    if (self.delegate && [self.delegate respondsToSelector:@selector(fileParser:parseProgress:)]) {
//                        [self.delegate fileParser:self
//                                    parseProgress:totalLength > 0 ? (float)index / (float)totalLength : 0];
//                    }
                    
                    float x, y, z;
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
                    
                    [byteData getBytes:&x length:sizeof(x)];
                    
                    index += 4;
                    
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
                    
                    [byteData getBytes:&y length:sizeof(y)];
                    
                    index += 4;
                    
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
                    
                    [byteData getBytes:&z length:sizeof(z)];
                    
                    index += 4;
                    
                    [object3D.vectorArray addObject:Vector3DMake(x, y, z)];
                }
            } else if (compareByte(byteData, @"<2041>")) {
                byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
                
                index += 2;
                
                short size;
                
                [byteData getBytes:&size length:sizeof(size)];
                
                for (int i = 0; i < size; i++) {
//                    if (self.delegate && [self.delegate respondsToSelector:@selector(fileParser:parseProgress:)]) {
//                        [self.delegate fileParser:self
//                                    parseProgress:totalLength > 0 ? (float)index / (float)totalLength : 0];
//                    }
                    
                    short a, b, c;
                    
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
                    [byteData getBytes:&a length:sizeof(a)];
                    
                    index += 2;
                    
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
                    [byteData getBytes:&b length:sizeof(b)];
                    
                    index += 2;
                    
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
                    [byteData getBytes:&c length:sizeof(c)];
                    
                    index += 4;
                    
                    [object3D.triangleArray addObject:TSimple3DMake(a, b, c)];
                }
                
            } else if (compareByte(byteData, @"<4041>")) {
                
                byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
                
                index += 2;
                short size;
                [byteData getBytes:&size length:sizeof(size)];
                for (int i = 0; i < size; i++) {
                    //                    if (self.delegate && [self.delegate respondsToSelector:@selector(fileParser:parseProgress:)]) {
                    //                        [self.delegate fileParser:self
                    //                                    parseProgress:totalLength > 0 ? (float)index / (float)totalLength : 0];
                    //                    }
                    
                    float x, y;
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
                    
                    [byteData getBytes:&x length:sizeof(x)];
                    
                    index += 4;
                    
                    byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
                    
                    [byteData getBytes:&y length:sizeof(y)];
                    
                    index += 4;
                    
                    [object3D.uvMapArray addObject:UVMake(x, y)];
                }
            } else {
                index += length - 6;
            }
            
            byteData = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:2];
            
            index += 2;
            
            chunkLength = [NSData dataWithBytes:((char *)[fileData bytes] + index)length:4];
            
            index += 4;
        }
        
        fileData = nil;
        
        return object3D;
    }
    
    return nil;
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

}

- (IBAction)fileButtonClick:(id)sender {
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setAllowedFileTypes:@[@"3ds"]];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *_selectedDoc = [[panel URLs] objectAtIndex:0];
            
            Object3DEntity *entity = [self parse3DSFileWithPath:_selectedDoc];
            
            if(entity != nil){
                _box = entity;
            }
            
            dirtyRect = SHRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
            
        }
        
    }];
    
    panel = nil;
}

@end
