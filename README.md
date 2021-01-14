# Azure Storage Swift

A SPM package for communicating with an azure storage account using Vapor.
This package is under development and not ready for production use.

## Features
- [x] Listing containers in a given storage account
- [ ] Listing blobs in a container
- [ ] Container management (including metadata)
- [ ] ACL Support
- [ ] SAS support
- [ ] CRUD operations for blobs in a container

I don't have plans to support TableQueue or the File service at this point in time

## Getting started


### 1) Create an azure storage configuration on your app

In your configure step add the following lines:

```swift
let configuration = StoregConfiguration("{CONNECTION_STRING")
application.azureStorageConfiguration = configuration
```

The connection string used can be found in your Azure Portal for your storage account.
If you are making use of the storage emulator, like [Azurite](https://github.com/Azure/Azurite), you can use the development connection string:`UseDevelopmentStorage=true`

### 2) Use an instance of AzureStorage in your eventLoop

To access an instance of azure storage you simply retrieve the service from your app, e.g.:

```swift
func someGetRequest(_ req: Request) throws -> HTTPStatus {
    _ = req.application.azureStorage.listContainers().map { containers -> () in
      // Do something with the listing of containers
    }
    throw Abort(.notImplemented)
}
```

More and better documentation including more api calls TBD. :)
