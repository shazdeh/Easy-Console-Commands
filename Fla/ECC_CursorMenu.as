import skse;

class ECC_CursorMenu extends MovieClip {

    function onLoad() {
    }

    function onMouseUp() {
        skse.SendModEvent( 'ECC_ClickCapture' );
    }

}