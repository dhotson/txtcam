all:
	gcc -o txtcam -framework Foundation -framework QTKit -framework Cocoa -framework CoreVideo -framework QuartzCore txtcam.m
