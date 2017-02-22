
role :web, 'concerto.local'                   # Your HTTP server, Apache/etc
role :app, 'concerto.local'                   # This may be the same as your `Web` server
role :db,  'concerto.local', primary: true    # This is where Rails migrations will run
