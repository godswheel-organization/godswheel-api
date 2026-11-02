# GodsWheel

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix 


## Frontend origins

Configure `FRONTEND_URL` as the canonical frontend URL used when generating email links.
Configure `FRONTEND_URLS` as a comma-separated allowlist of frontend origins permitted by
CORS and the refresh endpoint's Origin validation.

For example, to allow both the deployed frontend and local development:

```bash
FRONTEND_URL=https://godswheel.com
FRONTEND_URLS=https://godswheel.com,http://localhost:3000
```

`FRONTEND_URLS` entries must be origins only: scheme, host, and optional port. Do not
include paths, query strings, or fragments. If `FRONTEND_URLS` is omitted, it defaults
to the single origin configured by `FRONTEND_URL` (or `http://localhost:3000`).


## Tigris audio storage

Configure the private Tigris bucket and its S3-compatible credentials:

```bash
TIGRIS_BUCKET=godswheel-bucket
AWS_ACCESS_KEY_ID=tid_xxxxx
AWS_SECRET_ACCESS_KEY=tsec_xxxxx
AWS_REGION=auto
TIGRIS_ENDPOINT=https://t3.storage.dev
AUDIO_URL_TTL_SECONDS=14400
```

`TIGRIS_ENDPOINT`, `AWS_REGION`, and `AUDIO_URL_TTL_SECONDS` have defaults shown above. `AUDIO_URL_TTL_SECONDS` must be between 1 and 604800 seconds; the default is four hours. If Tigris supplies temporary credentials, configure `AWS_SESSION_TOKEN` as well. Keep all storage credentials exclusively on the backend.

Store the object key (not a URL) in `sermons.audio_url`, for example `sermons/your-audio-file.mp3`. `GET /api/v1/sermons/:id/audio` returns a fresh presigned URL and its `expiresAt` timestamp for a published sermon. The browser streams audio directly from the private Tigris bucket, including byte-range requests used for seeking. Request a new URL when playback is started again; seeking and pausing use the current URL. If a URL expires during playback, the frontend should request a fresh URL, restore the last playback position, and retry once.

Configure the bucket's CORS policy to allow `GET` and `HEAD` from each browser origin and expose `Accept-Ranges`, `Content-Length`, `Content-Range`, `Content-Type`, and `ETag`. The bucket does not need public access enabled.
