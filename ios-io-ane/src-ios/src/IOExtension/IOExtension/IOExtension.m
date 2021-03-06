#import "FlashRuntimeExtensions.h"
#import "../Objective-Zip/ZipFile.h"
#import "../Objective-Zip/ZipException.h"
#import "../Objective-Zip/FileInZipInfo.h"
#import "../Objective-Zip/ZipWriteStream.h"
#import "../Objective-Zip/ZipReadStream.h"

#pragma mark - merge rgba

FREObject ioext_mergeRgbaPerByte(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    
//    NSLog( @"IOExtension - ioext_mergeRgbaPerByte()" );
    
    // Get offset.
    uint32_t dataOffset;
    FREGetObjectAsUint32( argv[ 1 ], &dataOffset );
    
    // Get length.
    int32_t specifyLength;
    FREGetObjectAsInt32( argv[ 2 ], &specifyLength );
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    FREAcquireByteArray( objectByteArray, &byteArray );
    
    const uint32_t len = specifyLength >= 0 ? specifyLength : byteArray.length / 2;
    
//    NSLog( @"IOExtension - ioext_mergeRgbaPerByte()... dataOffset: %u, specifyLength: %i, byteArray.length: %u, len: %u", dataOffset, specifyLength, byteArray.length, len );
    
    const uint32_t rOffset = 1;
    const uint32_t gOffset = 2;
    const uint32_t bOffset = 3;
    const uint32_t aOffset = len + 3;
    uint8_t* data = byteArray.bytes;
    
    for (uint32_t i = dataOffset; i < dataOffset + len; i += 4) {
        const uint8_t r = data[i + rOffset];
        const uint8_t g = data[i + gOffset];
        const uint8_t b = data[i + bOffset];
        const uint8_t a = data[i + aOffset];
        
        data[i] = b;
        data[i+1] = g;
        data[i+2] = r;
        data[i+3] = a;
    }
    
    FREReleaseByteArray( objectByteArray );
    
    return NULL;
}

FREObject ioext_mergeRgbaPerInt(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    
//    NSLog( @"IOExtension - ioext_mergeRgbaPerInt()..." );
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    FREAcquireByteArray( objectByteArray, &byteArray );
//    NSLog( @"IOExtension - ioext_mergeRgbaPerInt() - byteArray length: %u", byteArray.length );
    
    const uint32_t aOffset = byteArray.length/8;
    uint32_t* data = (uint32_t*)byteArray.bytes;
    const uint32_t* end = data + aOffset;
    
//    NSLog( @"IOExtension - ioext_mergeRgbaPerInt() - data[0]: %u", data[0] );
//    NSLog( @"IOExtension - ioext_mergeRgbaPerInt() - data[aOffset]: %u", data[aOffset] );
    
    while (data < end) {
        const uint32_t rgbData = *data;
        const uint32_t alphaData = data[aOffset];
        const uint8_t r = rgbData & 0x0000ff00;
        const uint8_t g = rgbData & 0x00ff0000;
        const uint8_t b = rgbData & 0xff000000;
        const uint8_t a = alphaData & 0xff000000;
        
        *data++ = a | (r << 8) | (g >> 8) | (b >> 24);
    }
    
    FREReleaseByteArray( objectByteArray );
    
    return NULL;
}

#pragma mark - Read from disk

FREObject ioext_read(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
 
//    NSLog( @"IOExtension - ioext_read()..." );
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    
    // Get file name.
    uint32_t fileNameLength;
    const uint8_t *fileNameRaw;
    FREGetObjectAsUTF8( argv[ 1 ], &fileNameLength, &fileNameRaw );
    NSString *fileName = [ NSString stringWithUTF8String:(char*)fileNameRaw ];
//    NSLog( @"IOExtension - ioext_read() - target file name: %@", fileName );
    
    // Determine file path to read from.
    NSString *finalFileName = [ NSString stringWithFormat:@"Documents/%@", fileName ];
    NSString *filePath = [ NSHomeDirectory() stringByAppendingPathComponent:finalFileName ];
//    NSLog( @"IOExtension - ioext_read() - target file path: %@", filePath );
    
    // File -> NSData.
    NSData *data = [ NSData dataWithContentsOfFile:filePath ];
    
    // NSData -> ByteArray.
    FREObject bytesLength;
    FRENewObjectFromUint32( data.length, &bytesLength );
    FRESetObjectProperty( objectByteArray, (uint8_t *)"length", bytesLength, NULL );
    FREAcquireByteArray( objectByteArray, &byteArray );
    memcpy( byteArray.bytes, data.bytes, data.length );
    FREReleaseByteArray( objectByteArray );
    
    return NULL;
}

FREObject ioext_readWithDeCompression(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    
//    NSLog( @"IOExtension - ioext_readWithDeCompression()..." );
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    
    // Get file name.
    uint32_t fileNameLength;
    const uint8_t *fileNameRaw;
    FREGetObjectAsUTF8( argv[ 1 ], &fileNameLength, &fileNameRaw );
    NSString *fileName = [ NSString stringWithUTF8String:(char*)fileNameRaw ];
//    NSLog( @"IOExtension - ioext_readWithDeCompression() - target file name: %@", fileName );
    
    // Determine file path to read from.
    NSString *finalFileName = [ NSString stringWithFormat:@"Documents/%@", fileName ];
    NSString *filePath = [ NSHomeDirectory() stringByAppendingPathComponent:finalFileName ];
    
    // Unzip.
    ZipFile *unzipFile= [ [ ZipFile alloc ] initWithFileName:filePath mode:ZipFileModeUnzip ];
    NSArray *infos= [unzipFile listFileInZipInfos];
    FileInZipInfo *firstInfo = infos[ 0 ];
    [ unzipFile goToFirstFileInZip ];
//    NSLog( @"IOExtension - ioext_readWithDeCompression() - file size: %u", firstInfo.length );
    ZipReadStream *read= [ unzipFile readCurrentFileInZip ];
    NSMutableData *buffer = [ [ NSMutableData alloc ] initWithLength: firstInfo.length ];
    [ read readDataWithBuffer:buffer ];
    [ read finishedReading ];
    
    // NSData -> ByteArray.
    FREObject bytesLength;
    FRENewObjectFromUint32( buffer.length, &bytesLength );
    FRESetObjectProperty( objectByteArray, (uint8_t *)"length", bytesLength, NULL );
    FREAcquireByteArray( objectByteArray, &byteArray );
    memcpy( byteArray.bytes, buffer.bytes, buffer.length );
    FREReleaseByteArray( objectByteArray );
    
    [ unzipFile close ];
    [ unzipFile release ];
    
    return NULL;
}

#pragma mark - Write to disk

FREObject ioext_writeWithCompression(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    
//    NSLog(@"IOExtension - ioext_writeWithCompression()...");
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    FREAcquireByteArray( objectByteArray, &byteArray );
    NSData *data = [ NSData dataWithBytes:(void *)byteArray.bytes length:(NSUInteger)byteArray.length ];
//    NSLog(@"IOExtension - ioext_writeWithCompression() - bytes: %u", data.length );
    FREReleaseByteArray( objectByteArray );
    
    // Get file name.
    uint32_t fileNameLength;
    const uint8_t *fileNameRaw;
    FREGetObjectAsUTF8( argv[ 1 ], &fileNameLength, &fileNameRaw );
    NSString *fileName = [ NSString stringWithUTF8String:(char*)fileNameRaw ];
//    NSLog(@"IOExtension - ioext_writeWithCompression() - incoming file name: %@", fileName);
    
    // Determine file path to write to.
    NSString *finalFileName = [ NSString stringWithFormat:@"Documents/%@", fileName ];
//    NSLog(@"IOExtension - ioext_writeWithCompression() - finalFileName: %@", finalFileName);
    NSString *filePath = [ NSHomeDirectory() stringByAppendingPathComponent:finalFileName ];
//    NSLog(@"IOExtension - ioext_writeWithCompression() - filePath: %@", filePath);
    
    // Write using compression.
    ZipFile *zipFile= [ [ ZipFile alloc ] initWithFileName:filePath mode:ZipFileModeCreate ];
//    NSLog(@"IOExtension - ioext_writeWithCompression() - zipFile: %@", zipFile);
    ZipWriteStream *stream= [ zipFile writeFileInZipWithName:fileName compressionLevel:ZipCompressionLevelFastest ];
//    NSLog(@"IOExtension - ioext_writeWithCompression() - stream: %@", stream);
    [ stream writeData:data ];
    [ stream finishedWriting ];
    [ zipFile close ];
    [ zipFile release ];
    
    return NULL;
}

FREObject ioext_write(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    
//    NSLog(@"IOExtension - ioext_write()...");
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    FREAcquireByteArray( objectByteArray, &byteArray );
    NSData *data = [ NSData dataWithBytes:(void *)byteArray.bytes length:(NSUInteger)byteArray.length ];
    FREReleaseByteArray( objectByteArray );
    
    // Get file name.
    uint32_t fileNameLength;
    const uint8_t *fileNameRaw;
    FREGetObjectAsUTF8( argv[ 1 ], &fileNameLength, &fileNameRaw );
    NSString *fileName = [ NSString stringWithUTF8String:(char*)fileNameRaw ];
//    NSLog(@"IOExtension - ioext_write() - incoming file name: %@", fileName);
    
    // Determine file path to write to.
    NSString *finalFileName = [ NSString stringWithFormat:@"Documents/%@", fileName ];
    NSString *filePath = [ NSHomeDirectory() stringByAppendingPathComponent:finalFileName ];
    
    // Write without using compression.
    [ data writeToFile:filePath atomically:YES ];
    
    return NULL;
}

FREObject ioext_writeAsync(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
 
//    NSLog(@"IOExtension - ioext_writeAsync()...");
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    FREAcquireByteArray( objectByteArray, &byteArray );
    NSData *data = [ NSData dataWithBytes:(void *)byteArray.bytes length:(NSUInteger)byteArray.length ];
    FREReleaseByteArray( objectByteArray );
    
    // Get file name.
    uint32_t fileNameLength;
    const uint8_t *fileNameRaw;
    FREGetObjectAsUTF8( argv[ 1 ], &fileNameLength, &fileNameRaw );
    NSString *fileName = [ NSString stringWithUTF8String:(char*)fileNameRaw ];
    //    NSLog(@"IOExtension - ioext_writeAsync() - incoming file name: %@", fileName);
    
    // Determine file path to write to.
    NSString *finalFileName = [ NSString stringWithFormat:@"Documents/%@", fileName ];
    NSString *filePath = [ NSHomeDirectory() stringByAppendingPathComponent:finalFileName ];
    
    // Writing block.
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(queue, ^{
        
        // Write without using compression.
        [ data writeToFile:filePath atomically:YES ];
        
        // Notify.
        NSString *eventName = @"io/ane/asyncWriteComplete";
        const uint8_t* eventCode = (const uint8_t*) [eventName UTF8String];
        FREDispatchStatusEventAsync( ctx, eventCode, eventCode );
        
    });
    
    return NULL;
}

FREObject ioext_writeWithCompressionAsync(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    
//    NSLog(@"IOExtension - ioext_writeWithCompressionAsync()...");
    
    // Get byte array.
    FREByteArray byteArray;
    FREObject objectByteArray = argv[ 0 ];
    FREAcquireByteArray( objectByteArray, &byteArray );
    NSData *data = [ NSData dataWithBytes:(void *)byteArray.bytes length:(NSUInteger)byteArray.length ];
//    NSLog(@"IOExtension - ioext_writeWithCompressionAsync() - bytes: %u", data.length );
    FREReleaseByteArray( objectByteArray );
    
    // Get file name.
    uint32_t fileNameLength;
    const uint8_t *fileNameRaw;
    FREGetObjectAsUTF8( argv[ 1 ], &fileNameLength, &fileNameRaw );
    NSString *fileName = [ NSString stringWithUTF8String:(char*)fileNameRaw ];
//    NSLog(@"IOExtension - ioext_writeWithCompressionAsync() - incoming file name: %@", fileName);
    
    // Determine file path to write to.
    NSString *finalFileName = [ NSString stringWithFormat:@"Documents/%@", fileName ];
//    NSLog(@"IOExtension - ioext_writeWithCompressionAsync() - finalFileName: %@", finalFileName);
    NSString *filePath = [ NSHomeDirectory() stringByAppendingPathComponent:finalFileName ];
//    NSLog(@"IOExtension - ioext_writeWithCompressionAsync() - filePath: %@", filePath);
    
    // Writing block.
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(queue, ^{
        
        // Write using compression.
        ZipFile *zipFile= [ [ ZipFile alloc ] initWithFileName:filePath mode:ZipFileModeCreate ];
//        NSLog(@"IOExtension - ioext_writeWithCompressionAsync() - zipFile: %@", zipFile);
        ZipWriteStream *stream= [ zipFile writeFileInZipWithName:fileName compressionLevel:ZipCompressionLevelFastest ];
//        NSLog(@"IOExtension - ioext_writeWithCompressionAsync() - stream: %@", stream);
        [ stream writeData:data ];
        [ stream finishedWriting ];
        [ zipFile close ];
        [ zipFile release ];
        
        // Notify.
        NSString *eventName = @"io/ane/asyncWriteAndCompressComplete";
        const uint8_t* eventCode = (const uint8_t*) [eventName UTF8String];
        FREDispatchStatusEventAsync( ctx, eventCode, eventCode );
        
    });
    
    return NULL;
}

#pragma mark - AS3 bootstrap

void IOExtensionContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToTest, const FRENamedFunction** functionsToSet) {
    
    *numFunctionsToTest = 8;
    
    FRENamedFunction* func = (FRENamedFunction*) malloc(sizeof(FRENamedFunction) * *numFunctionsToTest);
    
    func[ 0 ].name = (const uint8_t*) "write";
    func[ 0 ].functionData = NULL;
    func[ 0 ].function = &ioext_write;
    
    func[ 1 ].name = (const uint8_t*) "writeWithCompression";
    func[ 1 ].functionData = NULL;
    func[ 1 ].function = &ioext_writeWithCompression;
    
    func[ 2 ].name = (const uint8_t*) "readWithDeCompression";
    func[ 2 ].functionData = NULL;
    func[ 2 ].function = &ioext_readWithDeCompression;
    
    func[ 3 ].name = (const uint8_t*) "read";
    func[ 3 ].functionData = NULL;
    func[ 3 ].function = &ioext_read;
    
    func[ 4 ].name = (const uint8_t*) "mergeRgbaPerByte";
    func[ 4 ].functionData = NULL;
    func[ 4 ].function = &ioext_mergeRgbaPerByte;
    
    func[ 5 ].name = (const uint8_t*) "mergeRgbaPerInt";
    func[ 5 ].functionData = NULL;
    func[ 5 ].function = &ioext_mergeRgbaPerInt;
    
    func[ 6 ].name = (const uint8_t*) "writeAsync";
    func[ 6 ].functionData = NULL;
    func[ 6 ].function = &ioext_writeAsync;
    
    func[ 7 ].name = (const uint8_t*) "writeWithCompressionAsync";
    func[ 7 ].functionData = NULL;
    func[ 7 ].function = &ioext_writeWithCompressionAsync;
    
    /* DO NOT FORGET TO INCREASE numFunctionsToTest! - AND make sure indices are right */
    
    *functionsToSet = func;
}

void IOExtensionInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet) {
    *extDataToSet = NULL;
    *ctxInitializerToSet = &IOExtensionContextInitializer;
}