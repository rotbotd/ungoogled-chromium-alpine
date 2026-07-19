{
  blobstore: {
    contentAddressableStorage: {
      grpc: {
        client: {
          address: 'tunnel:18980',
        },
      },
    },
    actionCache: {
      grpc: {
        client: {
          address: 'tunnel:18980',
        },
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
