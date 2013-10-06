`travis-senv` is a utility to make it easier to move secure key files in and out
of the Travis continuous integration environment.  You can find the general
instructions on [secure environments](http://about.travis-ci.org/docs/user/encryption-keys/) on the
Travis site, but this command takes care of splitting up larger files (e.g. SSH
private keys) into multiple environment variable so that they fit into the
keyspace.

It works as follwos:

* `travis-senv encrypt ~/.ssh/id_deploy_dsa my_travis_envs` will create a file
  called `my_travis_envs` that has the key/value pairs (suitably base64 encoded
  and chunked up)
* `cat my_travis_envs | travis encrypt -ps --add` while in the checked out
  repository you wish to add the secure keys to.  This will *modify* the `travis.yml`
  file and add lots of entries to it.
* Within your Travis testing script, install the `travis-senv` command.  I normally
  use it with an existing OCaml installation, but from scratch you just need these lines:

```
echo "yes" | sudo add-apt-repository ppa:avsm/ppa-testing
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
export OPAMYES=1
opam init 
opam install travis-senv
eval `opam config env`
```

* Once that's done, just `travis-senv decrypt > ~/.ssh/id_deploy_dsa` and it
  will redirect its standard output to the file you specified.

You can even add multiple files to the same installation by using the `-p
<prefix>` option to define a unique environment name for each file.  It doesn't
matter what the contents of the prefix is, as long as its a valid UNIX envvar
character (i.e. alphanumeric is safest).
