{
  blobstore: {
    contentAddressableStorage: {
      grpc: {
        client: {
          address: 'storage:8981',
        },
      },
    },
    actionCache: {
      completenessChecking: {
        backend: {
          grpc: {
            client: {
              address: 'storage:8981',
            },
          },
        },
        maximumTotalTreeSizeBytes: 64 * 1024 * 1024,
      },
    },
  },
  fileSystemAccessCache: {
    grpc: {
      client: {
        address: 'storage:8981',
      },
    },
  },
  maximumMessageSizeBytes: 16 * 1024 * 1024,
  global: {
    diagnosticsHttpServer: {
      httpServers: [{
        listenAddresses: [':80'],
        authenticationPolicy: { allow: {} },
      }],
      enablePrometheus: true,
      enablePprof: true,
      enableActiveSpans: true,
    },
  },
}
