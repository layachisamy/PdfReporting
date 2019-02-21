unit Unit2;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls;

type
  TForm2 = class(TForm)
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Déclarations privées }
    procedure ShwoReport;
  public
    { Déclarations publiques }
  end;

var
  Form2: TForm2;

implementation

{$R *.fmx}
   uses
     System.IOUtils,
     SM.Report,
     SM.PdfSection;

procedure TForm2.Button1Click(Sender: TObject);
begin
  ShwoReport
end;

procedure Tform2.ShwoReport;
Var
   DH  : TDocHeader;
   Rpt : TSMReport;
   S   : TStringList;
   K   : Integer;
   F   : String;
begin
    { Set file name}
	F :=TPath.Combine(TPath.GetSHAREDDocumentsPath,'Bon.pdf');
    if FileExists(F) then
       DeleteFile(PChar(F));
  ShowMessage(F);

    { Set Header Document}
	DH.Author   := 'Samy';
	DH.Producer := 'Samy';
	DH.Subject  := 'Demo';
	DH.Title    := 'Demo Pdf created by Delphi App';

	{ Set content Document}
	Rpt :=  TSMReport.Create(Self);
	Try
		S :=TStringList.Create;
        Try
			Rpt.PdfPage:= TPdfPage.Create;
      Rpt.PdfPage.LoadFromFile;{Load Default page settings =A4 }
      {you can update page size e.g:
         Rpt.PdfPage.PageWidth := CentToPt(21);
         Rpt.PdfPage.PageHeight := CentToPt(27.7)
         Etc...}
			S.Clear;
			{ Add text}
			S.Add('This is Blod text aligned to Center with 12 Font size');
      K:= Rpt.AddTxt(S,12,[TFontStyle.fsBold],TTextAlign.Center,tsLine);
			{ Draw Line}
			Rpt.CreateShape(K,tsLine,spEndHor,7);

			S.Clear;
			{ Add Other Text}
			S.Add('More text');
      K:= Rpt.AddTxt(S,12,[TFontStyle.fsBold],TTextAlign.Center,tsLine);
			{ Draw rectangle}
			Rpt.CreateShape(K,tsRectangle,spClient,7);

			Rpt.Compress := False;
      Rpt.SaveToFile(F);

		Finally
			S.free;
		End;
	Finally
		Rpt.Free;
	End;

End;
end.
