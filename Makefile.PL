use ExtUtils::MakeMaker;

WriteMakefile(
  ABSTRACT => "VMware's Lab Manager public and private API",
  AUTHOR   => 'Phil Pollard <bennie@cpan.org>',
  LICENSE  => 'artistic_2',
  NAME     => 'VMware::API::LabManager',
  VERSION  => '2.06',

  PREREQ_PM => {
          'SOAP::Lite' => '0.71',
          'perl' => '5.006',
          'Net::SSL' => 0,
          'Data::Dumper' => 0
        }
,

  ( $ExtUtils::MakeMaker::VERSION < 6.46
        ? ()
        : ( META_MERGE => {
                requires  => {perl => '5.006'},
                resources => {
                    # homepage => 'http://FIXME.org',
                    # license  => 'http://dev.perl.org/licenses/',
                    # MailingList => 'http://FIXME',
                    repository => {
                        type => 'git',
                        url  => 'git://github.com/bennie/perl-VMware-API-LabManager.git',
                        web  => 'http://github.com/bennie/perl-VMware-API-LabManager',
                    },
                    bugtracker => {
                        # mailto => '...',
                        web => 'https://rt.cpan.org/Dist/Display.html?Name=VMware-API-LabManager',
                    },

                },
                no_index => {directory => [qw/t/]},
            },
            META_ADD => {
                build_requires     => {},
                configure_requires => {}
            },
        )
    )

);