class CheatsheetItem extends MovieClip {

    /* ref */
    public var Label1_tf:TextField;
    public var Label2_tf:TextField;
    public var Label3_tf:TextField;
    public var Divider1_mc:MovieClip;
    public var Divider2_mc:MovieClip;

    /*config */
    public var padding:Number = 3;

    function onLoad() {
    }

    function setData(a_label1:String, a_label2:String, a_label3:String) {
        Label1_tf.noTranslate = true;
        Label1_tf.autoSize = 'left';
        Label2_tf.autoSize = 'left';
        Label3_tf.autoSize = 'left';
        Label1_tf.SetText(a_label1);
        Label2_tf.SetText(a_label2, true);
        Label3_tf.SetText(a_label3, true);
        var biggerHeight = Math.max(Label2_tf._height, Label3_tf._height);
        Divider1_mc._height = biggerHeight + ConsoleCheatsheet.itemMargin;
        Divider2_mc._height = biggerHeight + ConsoleCheatsheet.itemMargin;
    }

    function onRollOver() {
    }

    function onRollOut() {
    }
}