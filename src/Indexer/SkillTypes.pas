unit SkillTypes;

interface

type
  TIndexedSkill = record
    BodyHash: string;
    BodyMarkdown: string;
    Description: string;
    FileMtimeUtc: string;
    HasScripts: Integer;
    IndexedUtc: string;
    Name: string;
    RepoId: Integer;
    ScriptsCount: Integer;
    ScriptsExts: string;
    SkillFile: string;
    SkillRoot: string;
    SourceId: Integer;
    Tags: string;
  end;

implementation

end.
