threads_count = Integer(ENV.fetch('PUMA_THREADS', 5))
threads threads_count, threads_count

port ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'production')

workers 0
