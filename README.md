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
