unit SM.PdfSection;
interface

   uses System.Classes,System.SysUtils,System.Types,System.UITypes, FMX.Graphics,FMX.Types;
Type
  {Position of shape :
     spStartHor: Before paragraph Line Only,
     spEndHor:   After paragraph Line Only,
     spLeft:     Left of the paragraph Line Only,
     spRight:    Right paragraph "Line Only",
     spClient:   Make Paragraph text inside Rectangle or Circle }

  TShapePosition = (spNone,spStartHor,spEndHor,spLeft,spRight,spClient);
  TTypeShape =(tsNone,tsLine,tsRectangle,tsCircle);

  TPdfBaseShape = Packed Record
    TypeShape:    TTypeShape;
    ShapePosition:TShapePosition;
    LHeigt:       Integer ;
    StartPoint:   TPointF;
    EndPoint:     TPointF;
  public
    procedure ClearPdfBaseShape;
  End;

  TParagraph = Packed Record //class(TPersistent)
    Align:     TTextAlign;
    Font:      TFont;
    Text:      TStrings;
    fShape:    TPdfBaseShape;
   public
   Class Function Create : TParagraph ;static;
   procedure ClearParagraph;

  End;

  PParagraph = ^TParagraph;
  TDocSections = class(TList)
    protected
      function  GetItem(const Index: Integer): TParagraph;
      procedure SetItem(const Index: Integer; const Value: TParagraph);

    public
      destructor Destroy;
      function   Add(const Paragraph: TParagraph): Integer;
      procedure  Clear; override;
      procedure  Delete(const Index: Integer);
      procedure  Insert(const Index: Integer; const Parag: TParagraph);
      function   First: TParagraph;
      function   Last: TParagraph;
      procedure  SaveShape(const Index : Integer; PdfShape : TPdfBaseShape);
      procedure  UpdateStarPoint(const Index: Integer;const StrtP:TPointf;const ShapPos:TShapePosition = spNone);
      procedure  UpdateEndPoint(const Index: Integer;const EndP:TPointf;const ShapPos:TShapePosition = spNone);
      procedure  UpdatePosition(const Index: Integer;const StrtP,EndP:TPointf;const ShapPos:TShapePosition = spNone);
      function   RetrieveShape(const Index: Integer) :TPdfBaseShape;

      procedure  DrawShape(const Index:Integer;S:TStrings);
   property
      Items[const Index: Integer]: TParagraph read GetItem write SetItem; default;

 end;

implementation


//------------------------------------------------------------------------------
                       { TPdfBaseShape }
//------------------------------------------------------------------------------
procedure TPdfBaseShape.ClearPdfBaseShape;
begin
  Self := Default(TPdfBaseShape);
end;

{ TParagraph }
Class Function TParagraph.Create : TParagraph;
  Var AShape : TPdfBaseShape;
begin
  Result.Align := TTextAlign.Leading;
  Result.Font := TFont.Create;
  Result.Font.SetSettings('courrier',12,[]);
  Result.Text := TStringList.Create;
    AShape.TypeShape := tsNone;
    AShape.ShapePosition := spNone;
    AShape.LHeigt := 1;
    AShape.StartPoint := TPointF.Create(0,0);
    AShape.EndPoint := TPointF.Create(0,0);
  Result.fShape :=AShape;
end;

//------------------------------------------------------------------------------
procedure TParagraph.ClearParagraph;
begin
  Self := Default(TParagraph);
end;

//------------------------------------------------------------------------------
                       { TDocSections }
//------------------------------------------------------------------------------
function TDocSections.GetItem(const Index: Integer): TParagraph;
begin
  Result := PParagraph(inherited Items[Index])^;
end;

//------------------------------------------------------------------------------
procedure TDocSections.SetItem(const Index: Integer; const Value: TParagraph);
begin
  PParagraph(inherited Items[Index])^ := Value;
end;

//------------------------------------------------------------------------------
destructor TDocSections.Destroy;
begin
  Clear;
  inherited;
end;

//------------------------------------------------------------------------------
function TDocSections.Add(const Paragraph: TParagraph): Integer;
var
  PParag: PParagraph;
begin
  New(PParag);
  PParag^ := Paragraph;
  PParag.fShape.TypeShape:=tsNone;
  Result := inherited Add(PParag);
end;

//------------------------------------------------------------------------------
procedure TDocSections.Clear;
var  Index: Integer;
begin
 for Index := Count - 1 downto 0 do
 begin
   with PParagraph(inherited Items[Index])^ do
   begin
       if Assigned(Text) then
          Text.Free;
       if Assigned(Font) then
          Font.Free;
        fShape.ClearPdfBaseShape;
        ClearParagraph;
   end;
   Dispose(PParagraph(inherited Items[Index]));
 end;
 inherited Clear;
end;

//------------------------------------------------------------------------------
procedure TDocSections.Delete(const Index: Integer);
begin
   Dispose(PParagraph(inherited Items[Index]));
   inherited Delete(Index);
end;
//------------------------------------------------------------------------------

procedure TDocSections.Insert(const Index: Integer;
  const Parag: TParagraph);
var
  PParag: PParagraph;
begin
  New(PParag);
  PParag^ := Parag;
  inherited Insert(Index, PParag);
end;
//------------------------------------------------------------------------------

function TDocSections.First: TParagraph;
begin
  Result := PParagraph(inherited First())^;
end;
//------------------------------------------------------------------------------

function TDocSections.Last: TParagraph;
begin
  Result := PParagraph(inherited Last())^;
end;
//------------------------------------------------------------------------------

procedure  TDocSections.SaveShape(const Index : Integer;  PdfShape : TPdfBaseShape);
begin
  PParagraph(inherited Items[Index])^.fShape := PdfShape;
end;
//------------------------------------------------------------------------------

procedure  TDocSections.UpdateStarPoint(const Index: Integer;const StrtP:TPointf;const ShapPos:TShapePosition = spNone);
begin
 PParagraph(inherited Items[Index])^.fShape.StartPoint := StrtP;
 PParagraph(inherited Items[Index])^.fShape.ShapePosition := ShapPos;
end;
//------------------------------------------------------------------------------

procedure  TDocSections.UpdateEndPoint(const Index: Integer;const EndP:TPointf;const ShapPos:TShapePosition = spNone);
begin
 PParagraph(inherited Items[Index])^.fShape.EndPoint  := EndP;
 PParagraph(inherited Items[Index])^.fShape.ShapePosition := ShapPos;
end;
//------------------------------------------------------------------------------

procedure TDocSections.UpdatePosition (const Index: Integer;const StrtP,EndP:TPointf;const ShapPos:TShapePosition = spNone);
begin
 UpdateStarPoint(Index,StrtP,ShapPos);
 UpdateEndPoint(Index,EndP,ShapPos);
end;
//------------------------------------------------------------------------------

function TDocSections.RetrieveShape(const Index: Integer) :TPdfBaseShape;
begin
 Result := PParagraph(inherited Items[Index])^.fShape
end;
//------------------------------------------------------------------------------

procedure TDocSections.DrawShape(const Index:Integer;S:TStrings);
begin
 with PParagraph(inherited Items[Index])^.fShape Do
 begin
  if (not Assigned(S))or (TypeShape=tsNone) then
     Exit;

  S.Add('0 0 0 rg'); //Set text black color
  {
  For shapes color we must use Color Space declared in Font Object e.g:
     5 0 obj
    <</ProcSet[/PDF/Text]/
      Font <</F1 4 0 R>>
      /ColorSpace
      <</CS1
        [ /Lab <<
                /Range
                [-128 127 -128 127]
                /WhitePoint
                [ 0.951 1 1.089]
              >>
       ]
      >>
   >>
  endobj
  And use it inide BT - ET Section
   /CS1 cs
    /RelativeColormetricri
     63 127 127 sc
     ....
  }

  S.Add(FloatToStr((LHeigt/10))+ ' w'); //Line Width
  S.Add('[] 0 d');
  {  Dash line commands
     [] 0 d = no dash, solid, unbroken dash
     [3] 0 d =  3 units ON, 3Units Off, (- - - -)
     [2] 1 d =  1 ON 2 OFF, 2 ON 2 OFF (-  --  )
     [2 1] 0 d =  2 ON 1 OFF 2ON 1 OFF (--  -- )
     [3 5] 6 d = 2 OFF 3 ON 5OFF 3 ON 5 OFF (  ---     ---)
     [2 3] 11 d =1 ON 3 OFF  2 ON 3 OFF 2ON (-   --   --)
  }
  S.Add('q');//Save state
  case TypeShape of
          tsRectangle:
          begin
             S.Add(StartPoint.X.ToString+' '+
                   StartPoint.Y.ToString+' '+
                   (EndPoint.X-StartPoint.X).ToString+' '+
                   (EndPoint.Y-StartPoint.Y).ToString+' re');//X1,Y1, Length, Height rectabgle
             S.Add('S');//Stoke
             //s.Add('f');
             //We can add f command to fill the rectangle
          end;
          tsLine:
          begin
             case ShapePosition of
              TshapePosition.spStartHor:
              begin
                 S.Add(StartPoint.X.ToString+' '+StartPoint.Y.ToString+' m'); //Move to
                 S.Add(EndPoint.X.ToString+' '+StartPoint.Y.ToString+' l');
              end;
              TshapePosition.spEndHor:
              begin
                 S.Add(StartPoint.X.ToString+' '+EndPoint.Y.ToString+' m'); //Move to
                 S.Add(EndPoint.X.ToString+' '+EndPoint.Y.ToString+' l');
              End;
              TshapePosition.spLeft:
              begin
                 S.Add(StartPoint.X.ToString+' '+StartPoint.Y.ToString+' m'); //Move to
                 S.Add(StartPoint.X.ToString+' '+EndPoint.Y.ToString+' l');
              End;
              TshapePosition.spRight:
              begin
                 S.Add(EndPoint.X.ToString+' '+StartPoint.Y.ToString+' m'); //Move to
                 S.Add(EndPoint.X.ToString+' '+EndPoint.Y.ToString+' l');
              End
             end;
             S.Add('S');
          end;
          tsCircle:
          begin
            {There is no circle drawing command, so we can use Cubic Bezier commands to do the job
              For that we use this sequence of commands
              1- Set initial point : 1 0 0 1 X Y cm   (X,Y = Absolut point)
              1- Move to Center :  0 0 m   (0,0 = relative point)
              3- Specify the Cubic by 03 points : X1 Y2 X2 Y2 X3 Y3 c
              4- Repeat 3rd command until obtain the desired circle.
             Suggestion:
             Center Point = StrtP
             Radius = EndP.x
             }
             //todo
          end;
  end;
   S.Add('0 0 0 rg');
   S.Add('Q');//Restore state
 end;
end;
end.

