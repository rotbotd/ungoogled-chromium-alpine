local common = import 'worker-common.libsonnet';

{
  blobstore: common.blobstore,
  maximumMessageSizeBytes: common.maximumMessageSizeBytes,
  scheduler: { address: 'tunnel:18980' },
  global: common.global,
  buildDirectories: [{
    native: {
      buildDirectoryPath: '/worker/build',
      cacheDirectoryPath: '/worker/cache',
      maximumCacheFileCount: 100000,
      maximumCacheSizeBytes: 6 * 1024 * 1024 * 1024,
      cacheReplacementPolicy: 'LEAST_RECENTLY_USED',
    },
    runners: [{
      endpoint: { address: 'unix:///worker/runner' },
      concurrency: 4,
      instanceNamePrefix: 'alpine',
      platform: {
        properties: [
          { name: 'OSFamily', value: 'linux' },
          { name: 'container-image', value: 'docker://ungoogled-chromium-alpine-rbe' },
        ],
      },
      workerId: {
        provider: 'github-actions',
        run: std.extVar('GITHUB_RUN_ID'),
        matrix: std.extVar('RBE_WORKER_ID'),
      },
    }],
  }],
  inputDownloadConcurrency: 8,
  outputUploadConcurrency: 8,
  directoryCache: {
    maximumCount: 10000,
    maximumSizeBytes: 64 * 1024 * 1024,
    cacheReplacementPolicy: 'LEAST_RECENTLY_USED',
  },
}
