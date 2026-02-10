unit SkillTypes;

interface

type
  TIndexedSkill = record
    BodyHash: string;
    BodyMarkdown: string;
    Description: string;
    FileMtimeUtc: string;
    IndexedUtc: string;
    Name: string;
    RepoId: Integer;
    SkillFile: string;
    SkillRoot: string;
    SourceId: Integer;
    Tags: string;
  end;

implementation

end.
