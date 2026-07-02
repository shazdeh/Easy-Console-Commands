import skse;
import Shared.GlobalFunc;
import Console;

class EasyConsoleCommands extends MovieClip {

    public static var instance;

    /* stage elements */
    public var Console_mc:MovieClip;
    public var CommandHistory:TextField;
    public var CommandEntry:TextField;
    public var Commands:Array;
    public var Toggle_mc:MovieClip;

    // @api
    public var customCommands:Array;

    /* state vars */
    private var lastFormattedLine:Number = 0;
    private var textFormat:TextFormat;
    private var cachedTextColor:Number;
    private var ssCommandUsed:Boolean; /* whether "ss" command was used, from Skyrim Search */
    private var commandIndex:Number = 0; /* keep track of clicks on the same line */

    private var blockList:Array;

    function EasyConsoleCommands() {
        EasyConsoleCommands.instance = this;
    }

    function onLoad() {
        var consoleRoot = _parent._parent;
        Toggle_mc._visible = false;
        Console_mc = Console.ConsoleInstance;
        CommandHistory = Console_mc.CommandHistory;
        CommandEntry = Console_mc.CommandEntry;
        Commands = Console_mc.Commands;
        textFormat = new TextFormat();
        cachedTextColor = CommandHistory.getTextFormat().color;

        var _this = this;
        Console_mc.onMouseMove = function() {
            _this.highlight();
        }
        Key.addListener(this);
        Console_mc.cachedOnKeyDown = Console_mc.onKeyDown;
        Console_mc.onKeyDown = function() {
            _this.onKeyDownCallback();
        }

        /* flag, prevent reinjecting this movie into Console */
        consoleRoot.ECC_loaded = 1;
        customCommands = new Array();
        skse.SendModEvent( 'ECC_Loaded' );

        blockList = new Array();
        var loader:LoadVars = new LoadVars();
        loader.onData = onBlockListLoad;
        loader.load('Console_Blocklist.txt');
    }

    function onBlockListLoad(data:String) {
        this = EasyConsoleCommands.instance;
        if (data !== undefined && data !== '') {
            var lines:Array = normalizeNewlines(data).split('\n');
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].charAt(0) === '#') continue;
                blockList.push(lines[i]);
            }
        }
    }

    function isBlocked(command:String) : Boolean {
        for (var i = 0; i < blockList.length; i++) {
            if (command.indexOf(blockList[i]) !== -1) {
                return true;
            }
        }
        return false;
    }

    function onKeyDownCallback() {
        var sendingCustomCommand = false;
        if ( Key.getCode() == 13 || Key.getCode() == 108 ) {
            if (blockList.length > 0 && isBlocked(CommandEntry.text)) {
                Console.AddHistory("This command is blocked and cannot be used.\n");
                return;
            }

            var parts = CommandEntry.text.split( ' ' );
            var commandName = parts.shift().toLowerCase();
            for ( var i = 0; i < customCommands.length; i++ ) {
                if ( commandName === customCommands[i] ) {
                    sendingCustomCommand = true;
                    var numArg = 0;
                    if ( parts[0] ) {
                        numArg = parseInt( parts[0], 16 );
                    }
                    Console.AddHistory(CommandEntry.text + "\n");
                    skse.SendModEvent( 'ECC_Command_' + commandName, parts.join( ' ' ), numArg );
                    break;
                }
            }
            if ( ! sendingCustomCommand && commandName === 'ss' ) {
                ssCommandUsed = true;
            }
        }

        if ( sendingCustomCommand ) {
            Commands.push(CommandEntry.text);
            Console_mc.ResetCommandEntry();
        } else {
            Console_mc.cachedOnKeyDown();
        }
    }

    function handleClick() {
        if ( lastFormattedLine !== 0 ) {
            var command = help_getCommand( lastFormattedLine, CommandHistory.getLineText( lastFormattedLine ) );
            if ( ! command.length && ssCommandUsed ) {
                command = ss_getCommand( lastFormattedLine, CommandHistory.getLineText( lastFormattedLine ) );
            }

            if ( command.length ) {
                var currentCommandIndex = commandIndex++;
                if ( commandIndex === command.length ) {
                    commandIndex = 0;
                }

                CommandEntry.text = command[currentCommandIndex];
                Selection.setSelection(command[currentCommandIndex].length, command[currentCommandIndex].length); /* move caret to the end */
            }
        }
    }

    function highlight() {
        if ( ! Console_mc.Background.hitTest(_root._xmouse, _root._ymouse) ) {
            lastFormattedLine = 0;
            return;
        }
        var line = CommandHistory.getLineIndexAtPoint( CommandHistory._xmouse, CommandHistory._ymouse );
        if ( line ) {
            if ( lastFormattedLine === line ) {
				return;
			}

            /* reset the last highlightd line */
			var startIndex, finishIndex;
            startIndex = CommandHistory.getLineOffset(lastFormattedLine);
			finishIndex = CommandHistory.getLineLength(lastFormattedLine) + startIndex;
			textFormat.color = cachedTextColor;
			CommandHistory.setTextFormat(startIndex, finishIndex, textFormat);
			lastFormattedLine = line;
            commandIndex = 0;

            var lineText = CommandHistory.getLineText( line );

            if ( should_highlight( line, lineText ) ) {
                /* format the current line */
                startIndex = CommandHistory.getLineOffset(line);
                finishIndex = CommandHistory.getLineLength(line) + startIndex;
                textFormat.color = 0x00ffff;
                CommandHistory.setTextFormat(startIndex, finishIndex, textFormat);
            }
        } else {
            lastFormattedLine = 0;
        }
    }

    function should_highlight( lineIndex:Number, lineText:String ) : Boolean {
        if ( is_help_command_output( lineIndex, lineText ) ) {
            return true;
        } else if ( ssCommandUsed ) {
            var parts = lineText.split( ' | ' );
            if ( lineText.substr( 0, 8 ) !== ' form_id'
                && (
                    parts.length === 3 // ss cell
                    || parts.length === 4 // ss npc, quest, quest_stage
                )
            ) {
                return true;
            }
        }
    }

    function help_getCommand( lineIndex:Number, lineText:String ) : Array {
        var commands = [];
        var recordType = lineText.substr(0, 5).toUpperCase();
        if ( recordType === 'NPC_:' ) {
            var npcName = getNPCName(lineText);
            commands = [
                'MoveToPlayer "' + npcName + '"',
                'PlayerMoveTo "' + npcName + '"',
                'player.placeatme ' + getFormID( lineText ) + ' 1'
            ];
        } else if ( recordType === 'CELL:' ) {
            commands = [ 'coc ' + getFormEditorID(lineText) ];
        } else if ( recordType === 'BOOK:' || recordType === 'INGR:' || recordType === 'ARMO:' || recordType === 'MISC:' || recordType === 'WEAP:' || recordType === 'ALCH:' || recordType === 'KEYM:' || recordType === 'SCRL:' || recordType === 'AMMO:' || recordType === 'SLGM:' ) {
            var formId = getFormID( lineText );
            commands = [
                getCommandPrefix() + 'additem ' + formId + ' 1',
                getCommandPrefix() + 'removeitem ' + formId + ' 1',
                'player.placeatme ' + formId + ' 1',
                'player.equipitem ' + formId + ' 1',
                'player.unequipitem ' + formId + ' 1'
            ];
        } else if ( recordType === 'SPEL:' ) {
            var formId = getFormID( lineText );
            commands = [
                getCommandPrefix() + 'addspell ' + formId,
                getCommandPrefix() + 'hasspell ' + formId,
                getCommandPrefix() + 'removespell ' + formId
            ];
        } else if ( recordType === 'PERK:' ) {
            var formId = getFormID( lineText );
            commands = [
                getCommandPrefix() + 'addperk ' + formId,
                getCommandPrefix() + 'hasperk ' + formId,
                getCommandPrefix() + 'removeperk ' + formId
            ];
        } else if ( recordType === 'QUST:' ) {
            var formId = getFormEditorID(lineText);
            commands = [
                'getstage ' + formId,
                'sqs ' + formId + ' ; show quest stages',
                'completequest ' + formId,
                'movetoqt ' + formId,
                'resetquest ' + formId
            ];
        } else if ( recordType === 'LCTN:' ) {
            var formId = getFormID( lineText );
            commands = [
                'SetLocationCleared ' + formId + ' 1',
                'GetLocationCleared ' + formId
            ];
        } else if ( recordType === 'FACT:' ) {
            var formId = getFormID( lineText );
            commands = [
                getCommandPrefix() + 'addtofaction ' + formId + ' 0'
            ];
        } else if ( recordType === 'IDLE:' ) {
            commands = [
                getCommandPrefix() + 'playidle ' + getFormEditorID(lineText)
            ];
        } else if ( recordType === 'SHOU:' ) {
            var formId = getFormID( lineText );
            commands = [
                'unlockshout ' + formId,
                'learnshout ' + formId
            ];
        } else if ( lineText.substr(0, 6) === 'Stage ' ) {
            var sqsCommand = get_nearest_parent_command( 'sqs ', CommandHistory.getLineOffset( lineIndex ) );
            if ( sqsCommand !== '' ) {
                var sqsParts = sqsCommand.split( ' ' );
                commands = [
                    'setstage ' + sqsParts[1] + ' ' + lineText.substr( 6, lineText.lastIndexOf(':') - 6 )
                ];
            }
        } else if ( recordType === 'WRLD:' ) {
            commands = [ 'cow ' + getFormEditorID(lineText) + ' 0,0' ];
        } else if ( lineText.indexOf( ' CELL: ' ) !== -1 && lineText.substr( -2, 1 ) === '\'' ) { /* Exterior Cells lists */
            var formId = lineText.substring( lineText.lastIndexOf( ' ' ), lineText.length - 2 );
            commands = [ 'coc ' + formId ];
        }

        return commands;
    }

    /* looks value up in from startIndex and extract the whole line */
    function get_nearest_parent_command( value:String, startIndex:Number ) : String {
        var parentCommandStartIndex = CommandHistory.text.lastIndexOf( value, startIndex );
        var line:String = '';
        if ( parentCommandStartIndex !== -1 ) {
            var parentCommandEndIndex = CommandHistory.text.indexOf( String.fromCharCode(13), parentCommandStartIndex ); /* index of the last char */
            line = CommandHistory.text.substr( parentCommandStartIndex, parentCommandEndIndex - parentCommandStartIndex );
        }

        return line;
    }

    function is_help_command_output( lineIndex:Number, text:String ) : Boolean {
        var supportedTypes = [ 'NPC_', 'CELL', 'BOOK', 'INGR', 'ARMO', 'MISC', 'WEAP', 'ALCH', 'KEYM', 'SCRL', 'AMMO', 'SPEL', 'PERK', 'QUST', 'LCTN', 'FACT', 'IDLE', 'SHOU', 'SLGM', 'WRLD' ];
        var firstChars = text.substr(0, 5).toUpperCase();
        for ( var i = 0; i < supportedTypes.length; i++ ) {
            if ( firstChars === supportedTypes[ i ] + ':' ) {
                return true;
            }
        }
        if ( text.substr(0, 6) === 'Stage ' ) { /* result of "sqs" command */
            return true;
        } else if ( text.indexOf( ' CELL: ' ) !== -1 && text.substr( -2, 1 ) === "'" ) { /* Exterior Cells lists */
            return true;
        }

        return false;
    }

    function getFormID(lineText:String) : String {
        var start = lineText.indexOf('(') + 1;
        return lineText.substring(start, lineText.indexOf(')', start));
    }

    function getNPCName(lineText:String) : String {
        var start = lineText.indexOf('\'') + 1;
        return lineText.substring(start, lineText.indexOf('\'', start));
    }

    function getFormEditorID(lineText:String) {
        return lineText.substr( 6, lineText.lastIndexOf('(') - 7 );
    }

    function getCommandPrefix() {
        return 'player.';
    }

    /** Generate command input for Skyrim Search output */
    function ss_getCommand( lineIndex:Number, lineText:String ) : Array {
        var commands = [];
        lineText = GlobalFunc.StringTrim( ( lineText ) );
        var ssCommandText = get_nearest_parent_command( 'ss ', CommandHistory.getLineOffset( lineIndex ) );
        if ( ssCommandText ) {
            var ssCommandParts = ssCommandText.split( ' ' );
            if ( ssCommandParts[1] === 'npc' ) {
                var refId = lineText.substr( lineText.length - 8 );
                if ( refId && refId !== '| <null>' ) {
                    commands = [ '"' + refId + '".moveto player' ];
                }
            } else if ( ssCommandParts[1] === 'cell' ) {
                var arr = lineText.split( ' | ' );
                commands = [ 'coc ' + GlobalFunc.StringTrim( arr[1] ) ];
            } else if ( ssCommandParts[1] === 'quest' ) {
                var questId = lineText.substr( 0, 8 );
                commands = [ 'completequest ' + questId ];
            } else if ( ssCommandParts[1] === 'quest_stage' ) {
                var arr = lineText.split( ' | ' );
                commands = [ 'setstage ' + GlobalFunc.StringTrim( arr[1] ) + ' ' + GlobalFunc.StringTrim( arr[3] ) ];
            }
        }

        return commands;
    }

    // @api
    function setCustomCommands(data:String) {
        var newCommands = data.split( '|' );
        for ( var i = 0; i < newCommands.length; i++ ) {
            if ( newCommands[ i ] ) {
                customCommands.push( newCommands[ i ].toLowerCase() );
            }
        }
    }

    // @api
    function showCheatHotkey(keycode:Number) {
        var currentSelection:TextField = Console_mc.CurrentSelection;
        Toggle_mc.Hotkey_mc.gotoAndStop(keycode);
        Toggle_mc.Label_tf._x = Toggle_mc.Hotkey_mc._width;
        var points = { x : currentSelection._x, y : currentSelection._y };
        Console_mc.localToGlobal(points);
        Toggle_mc._xscale = 200;
        Toggle_mc._yscale = 200;
        Toggle_mc._x = points.x + (currentSelection._width - Toggle_mc._width);
        Toggle_mc._y = points.y - (currentSelection._height + 100);
        Toggle_mc._visible = true;
    }

    function normalizeNewlines(s:String):String {
        s = s.split("\r\n").join("\n");

        while (s.indexOf("\n\n") != -1) {
            s = s.split("\n\n").join("\n");
        }

        return s;
    }
}