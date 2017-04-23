# Only run coverage from linux release build on travis.
get(ENV, "TRAVIS_OS_NAME", "")       == "linux" || exit()
get(ENV, "TRAVIS_JULIA_VERSION", "") == "0.5"   || exit()

using Coverage

Codecov.submit(Codecov.process_folder())
