// Official HarmonyOS Design System SymbolGlyph Icon Builders
// Strictly uses official $r('sys.symbol.*') resources — zero text/Unicode icon substitutes.

@Builder
export function HmosSymbolIcon(res: Resource, sizeVp: number, colorHex: string | ResourceColor) {
  SymbolGlyph(res)
    .fontSize(sizeVp)
    .fontColor([colorHex])
}

@Builder
export function HmosIconButton(
  res: Resource,
  colorHex: string | ResourceColor,
  bgHex: string | ResourceColor,
  borderHex: string | ResourceColor,
  onClick: () => void,
  btnSizeVp: number = 30,
  iconSizeVp: number = 14
) {
  Button({ type: ButtonType.Normal }) {
    Row() {
      SymbolGlyph(res)
        .fontSize(iconSizeVp)
        .fontColor([colorHex])
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
  .width(btnSizeVp)
  .height(btnSizeVp)
  .backgroundColor(bgHex)
  .borderRadius(6)
  .border({ width: borderHex === Color.Transparent ? 0 : 1, color: borderHex, radius: 6 })
  .onClick(() => {
    onClick();
  })
}

@Builder
export function HmosIconTextButton(
  res: Resource,
  label: string,
  fgHex: string | ResourceColor,
  bgHex: string | ResourceColor,
  borderHex: string | ResourceColor,
  onClick: () => void,
  heightVp: number = 32,
  fontSizeVp: number = 12
) {
  Button({ type: ButtonType.Normal }) {
    Row({ space: 4 }) {
      SymbolGlyph(res)
        .fontSize(fontSizeVp + 1)
        .fontColor([fgHex])
      Text(label)
        .fontSize(fontSizeVp)
        .fontWeight(FontWeight.Medium)
        .fontColor(fgHex)
    }
    .padding({ left: 10, right: 10 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
  .height(heightVp)
  .backgroundColor(bgHex)
  .borderRadius(6)
  .border({ width: borderHex === Color.Transparent ? 0 : 1, color: borderHex, radius: 6 })
  .onClick(() => {
    onClick();
  })
}
