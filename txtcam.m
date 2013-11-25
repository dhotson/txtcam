#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

#include <stdio.h>
#include <sys/ioctl.h>
#include <math.h>
#include <signal.h>

@interface myThread:NSThread {
}
@end

@implementation myThread:NSThread

- (void)captureOutput:(QTCaptureOutput *)captureOutput didOutputVideoFrame:(CVImageBufferRef)videoFrame withSampleBuffer:(QTSampleBuffer *)sampleBuffer fromConnection:(QTCaptureConnection *)connection {
	@synchronized (self) {
		CIImage *image = [CIImage imageWithCVImageBuffer:videoFrame];
		CGSize size = image.extent.size;
		NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCIImage:image];

		int x;
		int y;

		int red;
		int green;
		int blue;

		printf("\033[0;0H"); // Move cursor to top right

		for (y=0; y<size.height; y += 1) {
			for (x=0; x<size.width; x++) {
				NSColor *color = [rep colorAtX:x y:y];

				red = (int)([color redComponent] * 255);
				green =	(int)([color greenComponent] * 255);
				blue = (int)([color blueComponent] * 255);

				printf("\033[48;2;%i;%i;%im ", red, green, blue);
			}

			if (y<size.height-1) printf("\n");
		}
	}
}

- (void)main {
	struct winsize max;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSArray *a = [QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo];
	QTCaptureDevice *cam = [a objectAtIndex:0];
	NSError *err;

	if ([cam open:&err] != YES) {
		NSLog(@"Error opening camera: %@", err);
	}

	QTCaptureDeviceInput *in = [[QTCaptureDeviceInput alloc] initWithDevice:cam];
	QTCaptureSession *session = [[QTCaptureSession alloc] init];

	if ([session addInput:in error:&err] != YES) {
		NSLog(@"Error adding input to capture session: %@", err);
	}

	// Grab decompressed output
	QTCaptureVideoPreviewOutput *previewOutput;
	previewOutput = [[QTCaptureVideoPreviewOutput alloc] init];
	[previewOutput setPixelBufferAttributes:@{(id)kCVPixelBufferWidthKey: @(64), (id)kCVPixelBufferHeightKey: @(48/2)}];

	previewOutput.delegate = self;
	int success = [session addOutput:previewOutput error:&err];
	if (!success) {
		NSLog(@"Error adding preview output to capture session: %@", err);
		exit(1);
	}

	printf("\033[2J"); // clear screen
	printf( "\x1B[?25l"); // disable cursor
	[session startRunning];

	while(1) {
		sleep(1);

		// Update preview size based on size of terminal
		ioctl(0, TIOCGWINSZ , &max);
		[previewOutput setPixelBufferAttributes:@{(id)kCVPixelBufferWidthKey: @(max.ws_col), (id)kCVPixelBufferHeightKey: @(max.ws_row)}];

		sleep(1);
	}
	[pool release];
}

@end

void intHandler() {
	printf("\033[0;0H"); // Move cursor to top right
	printf("\033[2J"); // clear screen
	printf("\x1B[?25h"); // re-enable cursor
	exit(1);
}

int main( int argc, const char *argv[]) {
	signal(SIGINT, intHandler);
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];
	[[[myThread alloc] init] start];
	[NSApp run];
	[pool release];

	return 0;
}