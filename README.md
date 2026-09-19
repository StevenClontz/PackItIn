# PackItIn
Rails app for managing a Cub Scout pack

## Stack

- Ruby on Rails 8.1, SQLite
- Tailwind CSS (`tailwindcss-rails`)
- [Devise](https://github.com/heartcombo/devise) authentication: `Family` signs in with a **username** and password (no email)
- [CanCanCan](https://github.com/CanCanCommunity/cancancan) authorization (see `app/models/ability.rb`)

## Development (GitHub Codespaces)

The repo includes a dev container (`.devcontainer/`). Open it in a Codespace and dependencies install and the database is prepared automatically (`bin/setup --skip-server`). Then:

```sh
bin/dev          # Rails server + Tailwind watcher on port 3000
bin/rails test   # run the test suite
```

Codespaces forwards port 3000; the `*.app.github.dev` host is allowed in `config/environments/development.rb`.
