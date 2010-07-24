use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'VMware::API::LabManager',
    'VERSION_FROM' => 'lib/VMware/API/LabManager.pm',
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/VMware/API/LabManager.pm',
       AUTHOR     => 'Phillip Pollard <bennie@cpan.org>') : ()),
);
