program Project2;

uses
  System.StartUpCopy,
  FMX.Forms,
  Unit2 in 'Unit2.pas' {Form2},
  SM.PdfSection in '..\SM.PdfSection.pas',
  SM.Report in '..\SM.Report.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
