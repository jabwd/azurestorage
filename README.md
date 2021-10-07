# Azure Storage Swift

A SPM package for communicating with an azure storage account using Vapor.
This package is under development and not ready for production use.

A separate package is also included called `AzureStorage` which does not depend on Vapor and can therefore be used anywhere where swift-nio is generally available.

## Features
- [x] Listing containers in a given storage account
- [x] Listing blobs in a container
- [x] Basic storage container management
- [x] Async blob download
- [x] Safari MP4 support
- [ ] ACL Support
- [ ] SAS support
- [x] CRUD operations for blobs in a container
- [ ] Improved error handling, especially XML errors returning from AZS
- [x] Basic storage queue's support
- [ ] Things I probably forgot about

I don't have plans to support TableQueue or the File service at this point in time

## Getting started

### 1) Create an azure storage configuration on your app

In your configure step add the following lines:

```swift
import VaporAzs

app.azureStorageConfiguration = try AzureStorage.configuration(Environment.get("AZURE_STORAGE_CONNECTION_STRING")!)
// Get access to the development storage:
let config = AzureStorage.Configuration()
// Alternatively, the dev connection string is also supported
let config = AzureStorage.Configuration("UseDevelopmentStorage=true")

```

The connection string used can be found in your Azure Portal for your storage account.
If you are making use of the storage emulator, like [Azurite](https://github.com/Azure/Azurite), you can use the development connection string:`UseDevelopmentStorage=true`
Your production string would look similar to this: `DefaultEndpointsProtocol=https;AccountName={ACCOUNTNAME};AccountKey={KEY};EndpointSuffix=core.windows.net`

### 2) Creating containers

To access an instance of azure storage you simply retrieve the service from your app, e.g.:

```swift
import VaporAzs

func someGetRequest(_ req: Request) throws -> HTTPStatus {
    _ = req.application.azureStorage.container.createIfNotExists("testContainer").whenSucceeded { _ in 
        // do your thing
    }
    throw Abort(.notImplemented)
}
```

### 3) Uploading blobs

Uploading works through a serious of blocks that all contain their own IDs, this library will return a blockID
on every succesful upload. The upload then can be finilaized by providing a list of blockIDs in a correct order.
You can technically create an async upload that will use out of order blocks, but providing them in the correct order
to reconstruct the file you wanted to upload is your responsibility.

Example:

```swift
func uploadBlock(_ req: Request) throws -> HTTPStatus {
    guard let uploadID = UUID(uuidString: req.parameters.get("id") ?? "") else {
        throw Abort(.badRequest)
    }
    return Upload.find(uploadID, on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { upload -> EventLoopFuture<HTTPStatus> in
            req.logger.info("Upload found, reading blob from body")
            return req.body.collect(max: MAX_FILESIZE).flatMap { data -> EventLoopFuture<HTTPStatus> in
                guard let data = data else {
                    return req.eventLoop.makeFailedFuture(Abort(.badRequest))
                }
                guard let buff = data.getBytes(at: 0, length: data.readableBytes) else {
                    return req.eventLoop.makeFailedFuture(Abort(.badRequest))
                }
                req.logger.info("Got uploaded body: \(buff.count)")
                return req.application.azureStorage.blob.uploadBlock(
                    Environment.value(for: .containerName),
                    blobName: upload.blobName.uuidString,
                    data: buff,
                    on: req.client
                ).flatMap { blockID -> EventLoopFuture<HTTPStatus> in
                    guard let blockID = blockID else {
                        return req.eventLoop.makeFailedFuture(UploadError.createBlockFailed)
                    }
                    req.logger.info("BlockID created \(blockID)")
                    upload.bytesWritten += buff.count
                    upload.blockIDs.append(blockID)
                    return upload.save(on: req.db).map { _ -> HTTPStatus in
                        .created
                    }
                }
            }
    }
}

func finalizeUpload(_ req: Request) throws -> HTTPStatus {
    guard let uploadID = UUID(uuidString: req.parameters.get("id") ?? "") else {
        throw Abort(.badRequest)
    }
    return Upload.find(uploadID, on: req.db).unwrap(or: Abort(.notFound)).flatMap { upload -> EventLoopFuture<UploadEntity.FinalizeResponse> in
        guard upload.fileSize == upload.bytesWritten else {
            return req.eventLoop.makeFailedFuture(Abort(
                .custom(
                    code: HTTPStatus.badRequest.code,
                    reasonPhrase: "Not enough bytes to complete upload, did you miss uploading some blocks?"
                )
            ))
        }
        req.logger.info("Found upload, sending blockIDs to blobstorage…")
        return req.application.azureStorage.blob.finalize(
            Environment.value(for: .containerName),
            blobName: upload.blobName.uuidString,
            list: upload.blockIDs,
            on: req.client
        ).flatMap { response -> EventLoopFuture<UploadEntity.FinalizeResponse> in
            if response.status != .created {
                return req.eventLoop.makeFailedFuture(UploadError.createBlockFailed)
            }
            // Be happy with a new blob in azure!
        }
    }
}
```
### 4) Downloading blobs synchronously

```swift
application.blobStorage.read(container, blobName: blobName, on: req.eventLoop)
```
The read method will return a promise witha ClientRespones, of which the body can etiher be kept in memory or stored in a file using NIO's `FileIO`

### 5) Downloading blobs asynchronously
This is mostly useful when you're trying to proxy certain things of blobstorage through your vapor backend, and don't want users to access blobstorage URLs directly. Additionally this has less of a performance and memory impact than asynhcronous downloads for responding directly to users.
```swift
let provisionalResponsePromise = try! req.application.azureStorage.blob.stream(
  blob: blobName,
  container: containerName,
  fileName: file.name, // Optionally: A filename, this will be attached in a header to ignore blob specific names
  with: req
)
```

More and better documentation including more api calls TBD. :)
