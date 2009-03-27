/*
 Copyright (c) 2009 by contributors:

 * James Hight (http://labs.zavoo.com/)
 * Richard R. Masters
 * Google Inc. (Brad Neuberg -- http://codinginparadise.org)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

package org.svgweb.core
{
    import org.svgweb.core.SVGViewer;
    import org.svgweb.utils.SVGColors;
    import org.svgweb.utils.SVGUnits;
    import org.svgweb.nodes.*;
    
    import flash.display.CapsStyle;
    import flash.display.DisplayObject;
    import flash.display.JointStyle;
    import flash.display.LineScaleMode;
    import flash.display.Shape;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.MouseEvent;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    /** Base node extended by all other SVG Nodes **/
    public class SVGNode extends Sprite
    {
        public static const ATTRIBUTES_NOT_INHERITED:Array = ['id', 'x', 'y', 'width', 'height', 'rotate', 'transform', 
                                        'gradientTransform', 'opacity', 'mask', 'clip-path', 'href', 'target', 'viewBox'];


        public namespace xlink = 'http://www.w3.org/1999/xlink';
        public namespace svg = 'http://www.w3.org/2000/svg';
        
        public var svgRoot:SVGSVGNode = null;
        public var isMask:Boolean = false;

        //Used for gradients
        public var xMin:Number;
        public var xMax:Number;
        public var yMin:Number;
        public var yMax:Number;

        protected var _parsedChildren:Boolean = false;
        public var _initialRenderDone:Boolean = false;

        protected var _firstX:Boolean = true;
        protected var _firstY:Boolean = true;

        protected var _xml:XML;
        protected var _invalidDisplay:Boolean = false;
        protected var _id:String = null;
        protected var _graphicsCommands:Array;
        protected var _styles:Object;

        protected var original:SVGNode;
        protected var _isClone:Boolean = false;
        protected var _clones:Array = new Array();


        /**
         * Constructor
         *
         * @param xml XML object containing the SVG document. @default null
         *
         * @return void.
         */
        public function SVGNode(svgRoot:SVGSVGNode, xml:XML = null, original:SVGNode = null):void {
            this.svgRoot = svgRoot;
            this.xml = xml;
            if (original) {
                this.original = original;
                this._isClone = true;
            }

            this.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            this.addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
        }


        /**
         * Parse the SVG XML.
         * This handles creation of child nodes.
         **/
        protected function parse():void {
            
            for each (var childXML:XML in this._xml.children()) {    

                if (childXML.nodeKind() == 'element') {

                    // This handle strange gradient bugs with negative transforms
                    // by separating the transform from every object
                    if (String(childXML.@['transform']) != "") {
                        var newChildXML:XML = childXML.copy();
                        var stubGroupXML:XML = <g></g>;
                        stubGroupXML.@['transform'] = newChildXML.@['transform'];
                        delete newChildXML.@['transform'];
                        stubGroupXML.appendChild(newChildXML.toXMLString());
                        newChildNode = new SVGGroupNode(this.svgRoot, stubGroupXML);
                        this.addChild(newChildNode);
                        continue;
                    }

                    // If the object has a gaussian filter, flash will blur the object mask, even
                    // if the mask is not drawn with a blur. This is not correct rendering.
                    // So, we use a stub parent object to hold the mask, in order to isolate
                    // the mask from the filter. A child is created for the original object,
                    // and the filter is applied to the child.
                    if (String(childXML.@['clip-path']) != "") {
                        var newChildXML:XML = childXML.copy();
                        var stubGroupXML:XML = <g></g>;
                        stubGroupXML.@['clip-path'] = newChildXML.@['clip-path'];
                        delete newChildXML.@['clip-path'];
                        stubGroupXML.appendChild(newChildXML.toXMLString());
                        newChildNode = new SVGGroupNode(this.svgRoot, stubGroupXML);
                        this.addChild(newChildNode);
                        continue;
                    }

                    var newChildNode:SVGNode = this.parseNode(childXML);
                    if (!newChildNode) {
                        this.dbg("did not add object!:" + childXML.localName());
                        continue;
                    }
                    this.addChild(newChildNode);
                }
            }
        }


        public function parseNode(childXML:XML):SVGNode {
            var childNode:SVGNode = null;
            var nodeName:String = childXML.localName();
                    
            nodeName = nodeName.toLowerCase();

            switch(nodeName) {
                case "a":
                    childNode = new SVGANode(this.svgRoot, childXML);
                    break;
                case "animate":
                    childNode = new SVGAnimateNode(this.svgRoot, childXML);
                    break;    
                case "animatemotion":
                    childNode = new SVGAnimateMotionNode(this.svgRoot, childXML);
                    break;    
                case "animatecolor":
                    childNode = new SVGAnimateColorNode(this.svgRoot, childXML);
                    break;    
                case "animatetransform":
                    childNode = new SVGAnimateTransformNode(this.svgRoot, childXML);
                    break;    
                case "circle":
                    childNode = new SVGCircleNode(this.svgRoot, childXML);
                    break;        
                case "clippath":
                    childNode = new SVGClipPathNode(this.svgRoot, childXML);
                    break;
                case "desc":
                    childNode = new SVGDescNode(this.svgRoot, childXML);
                    break;
                case "defs":
                    childNode = new SVGDefsNode(this.svgRoot, childXML);
                    break;
                case "ellipse":
                    childNode = new SVGEllipseNode(this.svgRoot, childXML);
                    break;
                case "filter":
                    childNode = new SVGFilterNode(this.svgRoot, childXML);
                    break;
                case "g":                        
                    childNode = new SVGGroupNode(this.svgRoot, childXML);
                    break;
                case "image":                        
                    childNode = new SVGImageNode(this.svgRoot, childXML);
                    break;
                case "line": 
                    childNode = new SVGLineNode(this.svgRoot, childXML);
                    break;    
                case "lineargradient": 
                    childNode = new SVGLinearGradient(this.svgRoot, childXML);
                    break;    
                case "mask":
                    childNode = new SVGMaskNode(this.svgRoot, childXML);
                    break;                        
                case "metadata":
                    childNode = new SVGMetadataNode(this.svgRoot, childXML);
                    break;
                case "namedview":
                    //Add Handling 
                    break;
                case "pattern":
                    childNode = new SVGPatternNode(this.svgRoot, childXML);
                    break;
                case "polygon":
                    childNode = new SVGPolygonNode(this.svgRoot, childXML);
                    break;
                case "polyline":
                    childNode = new SVGPolylineNode(this.svgRoot, childXML);
                    break;
                case "path":                        
                    childNode = new SVGPathNode(this.svgRoot, childXML);
                    break;
                case "radialgradient": 
                    childNode = new SVGRadialGradient(this.svgRoot, childXML);
                    break;    
                case "rect":
                    childNode = new SVGRectNode(this.svgRoot, childXML);
                    break;
                case "script":
                    childNode = new SVGScriptNode(this.svgRoot, childXML);
                    break;
                case "set":
                    childNode = new SVGSetNode(this.svgRoot, childXML);
                    break;
                case "stop":
                    childNode = new SVGStopNode(this.svgRoot, childXML);            
                    break;
                case "svg":
                    childNode = new SVGSVGNode(this.svgRoot, childXML);
                    break;                        
                case "symbol":
                    childNode = new SVGSymbolNode(this.svgRoot, childXML);
                    break;                        
                case "text":    
                    childNode = new SVGTextNode(this.svgRoot, childXML);
                    break; 
                case "title":    
                    childNode = new SVGTitleNode(this.svgRoot, childXML);
                    break; 
                case "tspan":                        
                    childNode = new SVGTspanNode(this.svgRoot, childXML);
                    break; 
                case "use":
                    childNode = new SVGUseNode(this.svgRoot, childXML);
                    break;
                case "null":
                    break;
                    
                default:
                    trace("Unknown Element: " + nodeName);
                    childNode = new SVGUnknownNode(this.svgRoot, childXML);
                    break;    
            }
            return childNode;
        }

        /**
         * Triggers on ENTER_FRAME event
         * Redraws node graphics if _invalidDisplay == true
         **/
        protected function drawNode(event:Event = null):void {

            if ( (this.parent != null) && (this._invalidDisplay) ) {
                this._invalidDisplay = false;
                if (this._xml != null) {
                
                    this.graphics.clear();
                    
                    if (!this._parsedChildren) {
                        this.parse();
                        this._parsedChildren = true;
                    }

                    // sets x, y, rotate, and opacity
                    this.setAttributes();

                    if (this.getAttribute('display') == 'none') {
                        this.visible = false;
                    }
                    else {
                        // <svg> nodes get an implicit mask of their height and width
                        if (this is SVGSVGNode) {
                            this.applyDefaultMask();
                        }
                        this.generateGraphicsCommands();
                        this.transformNode();
                        this.draw();

                        this.applyClipPathMask();
                        this.applyViewBox();
                        this.setupFilters();
                    }
                }
                
                this.removeEventListener(Event.ENTER_FRAME, drawNode);

                if (this.xml.@id)  {
                    this.svgRoot.invalidateReferers(this.xml.@id);
                }

                if (getPatternAncestor() != null) {
                    this.svgRoot.invalidateReferers(getPatternAncestor().id);
                }

            }
            if (!this._initialRenderDone && this.parent) {
                this.attachEventListeners();
                this._initialRenderDone = true;
                this.svgRoot.renderFinished();
            }
        }

        protected function setAttributes():void {
            this.loadAttribute('x');
            this.loadAttribute('y');
            this.loadAttribute('rotate','rotation');
            this.loadAttribute('opacity','alpha');
        }

        /**
         * Load an XML attribute into the current node
         * 
         * @param name Name of the XML attribute to load
         * @param field Name of the node field to set. If null, the name attribute will be used as the field attribute.
         **/ 
        protected function loadAttribute(name:String, field:String = null):void {
            if (field == null) {
                field = name;
            }
            var tmp:String = this.getAttribute(name);
            if (tmp != null) {
                if (name == 'x') {
                    this[field] = SVGColors.cleanNumber2(tmp, this.getWidth());
                    return;
                }
                if (name == 'y') {
                    this[field] = SVGColors.cleanNumber2(tmp, this.getHeight());
                    return;
                }
                this[field] = SVGColors.cleanNumber(tmp);
            }
        } 

        // <svg> and <image> nodes get an implicit mask of their height and width
        public function applyDefaultMask():void {
            if (   (this.getAttribute('width') != null)
                && (this.getAttribute('height') != null) ) {
                if (this.mask == null) {
                    var myMask:Shape = new Shape();
                    this.parent.addChild(myMask);
                    this.mask = myMask;
                }
                if (this.mask is Shape) {
                    Shape(this.mask).graphics.clear();
                    Shape(this.mask).graphics.beginFill(0x000000);
                    Shape(this.mask).graphics.drawRect(this.x, this.y, this.getWidth(), this.getHeight());
                    Shape(this.mask).graphics.endFill();
                }
            }
        }

        /** 
         * Called to generate AS3 graphics commands from the SVG instructions
         **/
        protected function generateGraphicsCommands():void {
            this._graphicsCommands = new  Array();    
        }

        /**
         * Perform transformations defined by the transform attribute 
         **/
        public function transformNode():void {

            this.transform.matrix = new Matrix();
            this.loadAttribute('x');    
            this.loadAttribute('y');

            // XXX hack because tspan x,y apparently replaces
            // the parent text x,y instead of offsetting the
            // parent like every other node. the 'correct'
            // calculation is commented out because it does
            // not work currently
            if (this is SVGTspanNode) {
                this.x = 0;
                this.y = 0;
                //this.x = this.x - this.parent.x;
                //this.y = this.y - this.parent.y;
            }
            
            this.loadAttribute('rotate', 'rotation');

            // Apply transform attribute 
            var trans:String = this.getAttribute('transform');
            if (trans) {
                this.transform.matrix = this.parseTransform(trans, this.transform.matrix.clone());
            }

        }

        public function parseTransform(trans:String, baseMatrix:Matrix = null):Matrix {
            if (!baseMatrix) {
                baseMatrix = new Matrix();
            }
            
            if (trans != null) {
                var transArray:Array = trans.match(/\S+\(.*?\)/sg);
                transArray.reverse();
                for each(var tran:String in transArray) {
                    var tranArray:Array = tran.split('(',2);
                    if (tranArray.length == 2)
                    {
                        var command:String = String(tranArray[0]);
                        var args:String = String(tranArray[1]);
                        args = args.replace(')','');
                        args = args.replace(/\s+/sg,","); //Replace spaces with a comma
                        args = args.replace(/,{2,}/sg,","); // Remove any extra commas
                        args = args.replace(/^,/, ''); //Remove leading comma
                        args = args.replace(/,$/, ''); //Remove trailing comma
                        var argsArray:Array = args.split(',');

                        var nodeMatrix:Matrix = new Matrix();
                        switch (command) {
                            case "matrix":
                                if (argsArray.length == 6) {
                                    nodeMatrix.a = argsArray[0];
                                    nodeMatrix.b = argsArray[1];
                                    nodeMatrix.c = argsArray[2];
                                    nodeMatrix.d = argsArray[3];
                                    nodeMatrix.tx = argsArray[4];
                                    nodeMatrix.ty = argsArray[5];
                                }
                                break;

                            case "translate":
                                if (argsArray.length == 1) {
                                    nodeMatrix.tx = argsArray[0]; 
                                }
                                else if (argsArray.length == 2) {
                                    nodeMatrix.tx = argsArray[0]; 
                                    nodeMatrix.ty = argsArray[1]; 
                                }
                                break;

                            case "scale":
                                if (argsArray.length == 1) {
                                    nodeMatrix.a = argsArray[0];
                                    nodeMatrix.d = argsArray[0];
                                }
                                else if (argsArray.length == 2) {
                                    nodeMatrix.a = argsArray[0];
                                    nodeMatrix.d = argsArray[1];
                                }
                                break;
                                
                            case "skewX":
                                nodeMatrix.c = Math.tan(argsArray[0] * Math.PI / 180.0);
                                break;
                                
                            case "skewY":
                                nodeMatrix.b = Math.tan(argsArray[0] * Math.PI / 180.0);
                                break;
                                
                            case "rotate":
                                if (argsArray.length == 3) {
                                    nodeMatrix.translate(-argsArray[1], -argsArray[2]);
                                    nodeMatrix.rotate(Number(argsArray[0])* Math.PI / 180.0);
                                    nodeMatrix.translate(argsArray[1], argsArray[2]); 
                                }
                                else {
                                    nodeMatrix.rotate(Number(argsArray[0])* Math.PI / 180.0);
                                }
                                break;
                                
                            default:
                                //this.dbg('Unknown Transformation: ' + command);
                        }
                        baseMatrix.concat(nodeMatrix);
                    }
                }
            }
            
            return baseMatrix;
        }

        
        protected function draw():void {
            this.graphics.clear();            

            var firstX:Number = 0;
            var firstY:Number = 0;

            for each (var command:Array in this._graphicsCommands) {
                switch(command[0]) {
                    case "SF":
                        this.nodeBeginFill();
                        break;
                    case "EF":
                        this.nodeEndFill();
                        break;
                    case "M":
                        this.graphics.moveTo(command[1], command[2]);
                        firstX = command[1];
                        firstY = command[2];
                        break;
                    case "L":
                        this.graphics.lineTo(command[1], command[2]);
                        break;
                    case "C":
                        this.graphics.curveTo(command[1], command[2],command[3], command[4]);
                        break;
                    case "Z":
                        this.graphics.lineTo(firstX, firstY);
                        break;
                    case "LINE":
                        this.nodeBeginFill();
                        this.graphics.moveTo(command[1], command[2]);
                        this.graphics.lineTo(command[3], command[4]);
                        this.nodeEndFill();                
                        break;
                    case "RECT":
                        this.nodeBeginFill();
                        if (command.length == 5) {
                            this.graphics.drawRect(command[1], command[2],command[3], command[4]);
                        }
                        else {
                            this.graphics.drawRoundRect(command[1], command[2],command[3], command[4], command[5], command[6]);
                        }
                        this.nodeEndFill();                
                        break;        
                    case "CIRCLE":
                        this.nodeBeginFill();
                        this.graphics.drawCircle(command[1], command[2], command[3]);
                        this.nodeEndFill();
                        break;
                    case "ELLIPSE":
                        this.nodeBeginFill();                        
                        this.graphics.drawEllipse(command[1], command[2],command[3], command[4]);
                        this.nodeEndFill();
                        break;
                }
            }
        }

        /** 
         * Called at the start of drawing an SVG element.
         * Sets fill and stroke styles
         **/
        protected function nodeBeginFill():void {
            //Fill
            var color_and_alpha:Array = [0, 0];
            var color_core:Number = 0;
            var color_alpha:Number = 0;
            var fill_alpha:Number = 0;

            var fill:String = this.getAttribute('fill');
            if ( (fill != 'none') && (fill != '') && (this.getAttribute('visibility') != 'hidden') ) {
                var matches:Array = fill.match(/url\(#([^\)]+)\)/si);
                if (matches != null && matches.length > 0) {
                    var fillName:String = matches[1];
                    this.svgRoot.addReference(this, fillName);
                    var fillNode:SVGNode = this.svgRoot.getNode(fillName);
                    if (!fillNode) {
                         // this happens normally
                         //this.dbg("Gradient " + fillName + " not (yet?) available for " + this.xml.@id);
                    }
                    if (fillNode is SVGGradient) {
                        SVGGradient(fillNode).beginGradientFill(this);
                    }
                    else if (fillNode is SVGPatternNode) {
                        SVGPatternNode(fillNode).beginPatternFill(this);
                    }
                }
                else {
                    color_and_alpha = SVGColors.getColorAndAlpha(fill);
                    color_core = color_and_alpha[0];
                    color_alpha = color_and_alpha[1];
                    fill_alpha = SVGColors.cleanNumber( this.getAttribute('fill-opacity') ) * color_alpha;
                    this.graphics.beginFill(color_core, fill_alpha);
                }
            }

            //Stroke
            var line_color:Number;
            var line_alpha:Number;
            var line_width:Number;

            var stroke:String = this.getAttribute('stroke');
            if ( (stroke == 'none') || (stroke == '') || (this.getAttribute('visibility') == 'hidden') ) {
                line_alpha = 0;
                line_color = 0;
                line_width = 0;
            }
            else {
                line_color = SVGColors.cleanNumber(SVGColors.getColor(stroke));
                line_alpha = SVGColors.cleanNumber(this.getAttribute('stroke-opacity'));
                line_width = SVGColors.cleanNumber(this.getAttribute('stroke-width'));
            }

            var capsStyle:String = this.getAttribute('stroke-linecap');
            if (capsStyle == 'round'){
                capsStyle = CapsStyle.ROUND;
            }
            else if (capsStyle == 'square'){
                capsStyle = CapsStyle.SQUARE;
            }
            else {
                capsStyle = CapsStyle.NONE;
            }
            
            var jointStyle:String = this.getAttribute('stroke-linejoin');
            if (jointStyle == 'round'){
                jointStyle = JointStyle.ROUND;
            }
            else if (jointStyle == 'bevel'){
                jointStyle = JointStyle.BEVEL;
            }
            else {
                jointStyle = JointStyle.MITER;
            }
            
            var miterLimit:String = this.getAttribute('stroke-miterlimit');
            if (miterLimit == null) {
                miterLimit = '4';
            }

            this.graphics.lineStyle(line_width, line_color, line_alpha, false, LineScaleMode.NORMAL,
                                    capsStyle, jointStyle, SVGColors.cleanNumber(miterLimit));

            if ( (stroke != 'none') && (stroke != '')  && (this.getAttribute('visibility') != 'hidden') ) {
                var strokeMatches:Array = stroke.match(/url\(#([^\)]+)\)/si);
                if (strokeMatches != null && strokeMatches.length > 0) {
                    var strokeName:String = strokeMatches[1];
                    this.svgRoot.addReference(this, strokeName);
                    var strokeNode:SVGNode = this.svgRoot.getNode(strokeName);
                    if (!strokeNode) {
                         // this happens normally
                         //this.dbg("stroke gradient " + strokeName + " not (yet?) available for " + this.xml.@id);
                    }
                    if (strokeNode is SVGGradient) {
                         SVGGradient(strokeNode).lineGradientStyle(this, line_alpha);
                    }
                }
            }

        }
        
        /** 
         * Called at the end of drawing an SVG element
         **/
        protected function nodeEndFill():void {
            this.graphics.endFill();
        }

        /**
         * Check value of x against _minX and _maxX, 
         * Update values when appropriate
         **/
        protected function setXMinMax(value:Number):void {          
            if (_firstX) {
                _firstX = false;
                this.xMax = value;
                this.xMin = value;
                return;
            }
            
            if (value < this.xMin) {
                this.xMin = value;
            }
            if (value > this.xMax) {
                this.xMax = value;
            }
        }
        
        /**
         * Check value of y against _minY and _maxY, 
         * Update values when appropriate
         **/
        protected function setYMinMax(value:Number):void {
            if (_firstY) {
                _firstY = false;
                this.yMax = value;
                this.yMin = value;
                return;
            }
            
            if (value < this.yMin) {
                this.yMin = value;
            }
            if (value > this.yMax) {
                this.yMax = value;
            }
        }

        public function applyViewBox():void {
            var newMatrix:Matrix = this.transform.matrix.clone();

            // Apply viewbox transform
            var viewBox:String = this.getAttribute('viewBox');
            var preserveAspectRatio:String = this.getAttribute('preserveAspectRatio');

            if ( (viewBox != null) || (preserveAspectRatio != null) ) {

                if (preserveAspectRatio == null) {
                    preserveAspectRatio = 'xMidYMid meet';
                }

                /**
                 * Canvas, the viewport
                 **/
                var canvasWidth:Number = this.getWidth();
                var canvasHeight:Number = this.getHeight();

                /**
                 * Viewbox
                 **/
                var viewX:Number;
                var viewY:Number;
                var viewWidth:Number;
                var viewHeight:Number;
                if (viewBox != null) {
                    var points:Array = viewBox.split(/\s+/);
                    viewX = SVGColors.cleanNumber(points[0]);
                    viewY = SVGColors.cleanNumber(points[1]);
                    viewWidth = SVGColors.cleanNumber(points[2]);
                    viewHeight = SVGColors.cleanNumber(points[3]);
                }
                else {
                    viewX = 0;
                    viewY = 0;
                    viewWidth = canvasWidth;
                    viewHeight = canvasHeight;
                }


                var oldAspectRes:Number = viewWidth / viewHeight;
                var newAspectRes:Number = canvasWidth /  canvasHeight;
                var cropWidth:Number;
                var cropHeight:Number;

                var alignMode:String = preserveAspectRatio.substr(0,8);
                var meetOrSlice:String = 'meet';
                if (preserveAspectRatio.indexOf('slice') != -1) {
                    meetOrSlice = 'slice';
                }

                /**
                 * Handle Scaling
                 **/
                if (alignMode == 'none') {
                    // stretch to fit viewport width and height

                    cropWidth = canvasWidth;
                    cropHeight = canvasHeight;
                }
                else {
                    if (meetOrSlice == 'meet') {
                        // shrink to fit inside viewport

                        if (newAspectRes > oldAspectRes) {
                            cropWidth = canvasHeight * oldAspectRes;
                            cropHeight = canvasHeight;
                        }
                        else {
                            cropWidth = canvasWidth;
                            cropHeight = canvasWidth / oldAspectRes;
                        }
    
                    }
                    else {
                        // meetOrSlice == 'slice'
                        // Expand to cover viewport.

                        if (newAspectRes > oldAspectRes) {
                            cropWidth = canvasWidth;
                            cropHeight = canvasWidth / oldAspectRes;
                        }
                        else {
                            cropWidth = canvasHeight * oldAspectRes;
                            cropHeight = canvasHeight;
                        }
    
                    }
                }
                var scaleX:Number = cropWidth / viewWidth;
                var scaleY:Number = cropHeight / viewHeight;
                newMatrix.translate(-viewX, -viewY);
                newMatrix.scale(scaleX, scaleY);

                /**
                 * Handle Alignment
                 **/
                var borderX:Number;
                var borderY:Number;
                var translateX:Number;
                var translateY:Number;
                if (alignMode != 'none') {
                    translateX=0;
                    translateY=0;
                    var xAlignMode:String = alignMode.substr(0,4);
                    switch (xAlignMode) {
                        case 'xMin':
                            break;
                        case 'xMax':
                            translateX = canvasWidth - cropWidth;
                            break;
                        case 'xMid':
                        default:
                            borderX = canvasWidth - cropWidth;
                            translateX = borderX / 2.0;
                            break;
                    }
                    var yAlignMode:String = alignMode.substr(4,4);
                    switch (yAlignMode) {
                        case 'YMin':
                            break;
                        case 'YMax':
                            translateY = canvasHeight - cropHeight;
                            break;
                        case 'YMid':
                        default:
                            borderY = canvasHeight - cropHeight;
                            translateY = borderY / 2.0;
                            break;
                    }
                    newMatrix.translate(translateX, translateY);
                }
            }

            this.transform.matrix = newMatrix;

        }


        protected function applyClipPathMask():void {
            var attr:String;
            var match:Array;
            var node:SVGNode;
            var matrix:Matrix;
            var isMask:Boolean = true;

            attr = this.getAttribute('mask');
            if (!attr) {
                attr = this.getAttribute('clip-path');
            }

            if (attr) {
               match = attr.match(/url\(\s*#(.*?)\s*\)/si);
               if (match.length == 2) {
                   attr = match[1];
                   node = this.svgRoot.getNode(attr);
                   if (node) {
                       if (this.parent is SVGNode) {

                           this.removeMask();

                           var newMask:SVGNode = node.clone();
                           this.parent.addChild(newMask);

                           this.mask = newMask;

                           newMask.visible = true;
                           this.cacheAsBitmap = true;
                           newMask.cacheAsBitmap = true;

                       }
                   }
               }
            }
        }

        protected function removeMask():void {
            if (this.mask) {
                this.mask.parent.removeChild(this.mask);
                this.mask = null;
            }
        }

        /**
         * Add any assigned filters to node
         **/
        protected function setupFilters():void {
            var filterName:String = this.getAttribute('filter');
            if ((filterName != null)
                && (filterName != '')) {
                var matches:Array = filterName.match(/url\(#([^\)]+)\)/si);
                if (matches.length > 0) {
                    filterName = matches[1];
                    var filterNode:SVGNode = this.svgRoot.getNode(filterName);
                    if (filterNode) {
                        this.filters = SVGFilterNode(filterNode).getFilters(this);
                    }
                    else {
                        //this.dbg("filter " + filterName + " not (yet?) available for " + this.xml.@id);
                        // xxx add reference
                    }
                }
            }
        }

        protected function attachEventListeners():void {
            var action:String;

            action = this.getAttribute("onclick", null, false);
            if (action)
                this.svgRoot.addActionListener(MouseEvent.CLICK, this);

            action = this.getAttribute("onmousedown", null, false);
            if (action)
                this.svgRoot.addActionListener(MouseEvent.MOUSE_DOWN, this);

            action = this.getAttribute("onmouseup", null, false);
            if (action)
                this.svgRoot.addActionListener(MouseEvent.MOUSE_UP, this);

            action = this.getAttribute("onmousemove", null, false);
            if (action)
                this.svgRoot.addActionListener(MouseEvent.MOUSE_MOVE, this);

            action = this.getAttribute("onmouseover", null, false);
            if (action)
                this.svgRoot.addActionListener(MouseEvent.MOUSE_OVER, this);

            action = this.getAttribute("onmouseout", null, false);
            if (action)
                this.svgRoot.addActionListener(MouseEvent.MOUSE_OUT, this);

        }
                

        /*
         * Node registration triggered by stage add / remove
         */

        protected function onAddedToStage(event:Event):void {
            this.registerID();
            if (this.original) {
                this.original.registerClone(this);
            }
        }

        protected function onRemovedFromStage(event:Event):void {
            this.unregisterID();
            if (this.original) {
                this.original.unregisterClone(this);
            }
        }

        protected function registerID():void {
            if (this._isClone || (getMaskAncestor() != null)) {
                return;
            }

            var id:String = this.getAttribute('id');

            if (id == _id) {
                return;
            }

            if (_id) {
                this.svgRoot.unregisterNode(this);
            }

            if (id && id != "") {
                _id = id;
                this.svgRoot.registerNode(this);
            }
        }

        protected function unregisterID():void {
            if (this._id) {
                this.svgRoot.unregisterNode(this);
                _id = null;
            }
        }

        /*
         * Attribute Handling
         */

        /**
         * @param attribute Attribute to retrieve from SVG XML
         * 
         * @param defaultValue Value to return if attribute is not found
         * 
         * @param inherit If attribute is not set in this node try to retrieve it from the parent node
         * 
         * @return Returns the value of defaultValue
         **/
        public function getAttribute(name:String, defaultValue:* = null, inherit:Boolean = true):* {            
            var value:String = this._getAttribute(name);
            
            if (value == "inherit") {
                value = null;
            }
            
            if (value) {
                return value;
            }
            
            if (ATTRIBUTES_NOT_INHERITED.indexOf(name) != -1) {            
                return defaultValue;        
            }
            
            if (inherit && (this.parent is SVGNode)) {
                return SVGNode(this.parent).getAttribute(name, defaultValue);
            }
            
            return defaultValue;            
        }
        
        /**
         *
         * This method retrieves the attribute from the current node only and is
         * used as a helper for getAttribute, which has css parent inheritance logic.
         *
         **/
        protected function _getAttribute(name:String):String {
            var value:String;
            
            // If we are rendering a mask, then use a simple black fill.
            if (this.getMaskAncestor() != null) {

                if (  (name == 'opacity')
                    || (name == 'fill-opacity')
                    || (name == 'stroke-width')
                    || (name == 'stroke-opacity') ) {
                    return '1';
                }

                if (name == 'fill') {
                    return 'black';
                }

                if (name == 'stroke') {
                    return 'none';
                }

                if (name == 'filter') {
                    return null;
                }
            }
           
            if (name == "href") {
                //this._xml@href handled normally
                value = this._xml.@xlink::href;                             
                if (value && (value != "")) {
                    return value;
                }
            }

            if (this.original && (this.parent is SVGUseNode)) {
                //Node is the top level of a clone
                //Check for an override value from the parent
                value = SVGNode(this.parent).getAttribute(name, null, false);
                if (value) {
                    return value;
                }
            }
           
            var xmlList:XMLList = this._xml.attribute(name);
            
            if (xmlList.length() > 0) {
                return xmlList[0].toString();
            }   
                     
            if (_styles.hasOwnProperty(name)) {
                return (_styles[name]);
            }
 
            return null;
        }



        public function setAttribute(name:String, value:String):void {
            if (name == "style") {
                this._xml.@style = value;
                this.parseStyle();
            }
            else {
                if (this._styles.hasOwnProperty(name)) {
                    this._styles[name] = value;
                    updateStyle();
                }
                else {
                    this._xml.@[name] = value;
                }
            }
            
            switch (name) {
                case 'transform':
                case 'viewBox':
                case 'x':
                case 'y':
                case 'rotation':
                    this.transformNode();
                    this.applyViewBox();
                    break;

                default:
                    this.invalidateDisplay();
                    if (   (name == 'display' || name == 'visibility')
                        || (name == 'style' &&
                                (   (value.indexOf('visibility') != -1 )
                                 || (value.indexOf('display') != -1 ) ) ) ) {
                        this.invalidateChildren();
                    }
                    break;
            }
            this.updateClones();
            if (getPatternAncestor() != null) {
                this.svgRoot.invalidateReferers(getPatternAncestor().id);
            }

        }

        private function parseStyle():void {
            //Get styling from XML attribute 'style'
            _styles = new Object();
            
            var xmlList:XMLList = this._xml.attribute('style');
            if (xmlList.length() > 0) {
                var styleString:String = xmlList[0].toString();
                
                // only one style value given, with no trailing semicolon?
                if (this._xml.@style.length()  && styleString.indexOf(';') == -1) {
                    // update our internal string to be correct moving forward
                    this._xml.@style = styleString + ';';
                    styleString += ';';
                }
                
                var styles:Array = [] = styleString.split(';');
                for each(var style:String in styles) {
                    var styleSet:Array = style.split(':');
                    if (styleSet.length == 2) {
                        var attrName = SVGColors.trim(styleSet[0]);
                        var attrValue = SVGColors.trim(styleSet[1]);
                        
                        this._styles[attrName] = attrValue;
                    }
                }
            }
        }
 
       /**
         * Update style attribute from _styles
         * <node style="...StyleString...">
         * 
         **/ 
        private function updateStyle():void {
            var newStyleString:String = '';
            
            for (var key:String in this._styles) {
                if (newStyleString.length > 0) {
                    newStyleString += ';';
                }
                newStyleString += key + ':' + this._styles[key];
            }
            
            this._xml.@style = newStyleString;
        }
        
        /**
         * Returns true if this node can have text children. Subclasses
         * should override this if they want to have text node children.
         */
        public function hasText():Boolean {
            return false;
        }
        
        /**
         * Returns any text content this node might have as a child.
         */
        public function getText():String {
            return this._xml.text().toString();
        }
        
        /**
         * Sets any text content this node might have as a child.
         */
        public function setText(newValue):String {
            // subclasses should implement this if they want to have text
            throw new Error("Unimplemented");
        }

        /**
         * Force a redraw of a node
         **/
        public function invalidateDisplay():void {
            if (this._invalidDisplay == false) {
                this._invalidDisplay = true;
                this.addEventListener(Event.ENTER_FRAME, drawNode);                
            }            
        }

        public function invalidateChildren():void {
            var child:DisplayObject;
            for (var i:uint = 0; i < this.numChildren; i++) {
                child = this.getChildAt(i);
                if (child is SVGNode) {
                    SVGNode(child).invalidateDisplay();
                    SVGNode(child).invalidateChildren();
                }
            }
        }
 
        /*
         * Clone Handlers
         */

        public function clone():SVGNode {
            var nodeClass:Class = getDefinitionByName(getQualifiedClassName(this)) as Class;
            var newXML:XML = this._xml.copy();

            var node:SVGNode = new nodeClass(this.svgRoot, newXML, this) as SVGNode;

            return node;
        }

        public function registerClone(clone:SVGNode):void {
            if (this._clones.indexOf(clone) == -1) {
               this._clones.push(clone);
            }
        }

        public function unregisterClone(clone:SVGNode):void {
            var index:int = this._clones.indexOf(clone);
            if (index > -1) {
                this._clones = this._clones.splice(index, 1);
            }
        }

        protected function updateClones():void {
            for (var i:uint = 0; i < this._clones.length; i++) {
               SVGNode(this._clones[i]).xml = this._xml.copy();
            }
        }

        public function get isClone():Boolean {
            return this._isClone;
        }

        /*
         * Misc Functions
         */
         
        /** Appends an SVGNode both to our display list as well as to our
          * XML.
          **/
        public function appendChild(child:SVGNode):SVGNode {
            this._xml.appendChild(child._xml);
            this.addChild(child);
            this.invalidateDisplay();

            return child;
        }

        /**
         *
         **/
        override public function addChild(child:DisplayObject):DisplayObject {
            if (child is SVGNode) {
                this.svgRoot.renderPending();
            }
            super.addChild(child);
            return child;
        }

        /**
         * Remove all child nodes
         **/        
        protected function clearChildren():void {
            while(this.numChildren) {
                this.removeChildAt(0);
            }
        }
        
        override public function removeChild(child:DisplayObject):DisplayObject {
            super.removeChild(child);
            if (child is SVGNode) {
                var node:SVGNode = child as SVGNode;
                
                // unregister the element
                var id:String = node._xml.@id;
                if (id != "") {
                    this.svgRoot.unregisterNode(id);
                } else {
                    this.err('Programming error: ID required for removeChild');
                    throw new Error('Programming error: ID required for removeChild');
                }
                
                // remove from our XML children
                for (var i = 0; i < this._xml.children().length(); i++) {
                    if (this._xml.children()[i] == node._xml) {
                        delete this._xml.children()[i];
                        break;
                    }
                }
                
                this.invalidateDisplay();
            }
            
            return child;
        }
        
        /**
         * Adds newChild before refChild. Position is the position of refChild
         * to add newChild before.
         */
        public function insertBefore(position, newChild, refChild) {
            if (position == 0) {
                this._xml.*[0] = newChild + this._xml.*[0];
            } else {
                this._xml.*[position - 1] += newChild;
            }
            super.addChildAt(newChild, position);
            this.invalidateDisplay();
        }

        public function getWidth():Number {
            var parentWidth:Number=0;
            if (this.parent is SVGViewer) {
                parentWidth=SVGViewer(this.parent).getWidth();
            }
            if (this.parent is SVGNode) {
                parentWidth=SVGNode(this.parent).getWidth();
            }
            if (this.getAttribute('width') != null) {
                return SVGColors.cleanNumber2(this.getAttribute('width'), parentWidth);
            }

            // defaults to 100%
            return parentWidth;
        }

        public function getHeight():Number {
            var parentHeight:Number=0;
            if (this.parent is SVGViewer) {
                parentHeight=SVGViewer(this.parent).getHeight();
            }
            if (this.parent is SVGNode) {
                parentHeight=SVGNode(this.parent).getHeight();
            }
            if (this.getAttribute('height') != null) {
                return SVGColors.cleanNumber2(this.getAttribute('height'), parentHeight);
            }

            // defaults to 100%
            return parentHeight;
        }

        public function getMaskAncestor():SVGNode {
            var node:DisplayObject = this;
            if ( (node is SVGNode) && SVGNode(node).isMask)
                return SVGNode(node);
            while (node && !(node is SVGSVGNode)) {
                node=node.parent;
                if (node && (node is SVGNode) && SVGNode(node).isMask)
                    return SVGNode(node);
            }
            return null;
        }

        public function getPatternAncestor():SVGPatternNode {
            var node:SVGNode = this;
            while (node && !(node is SVGSVGNode)) {
                node=SVGNode(node.parent);
                if (node is SVGPatternNode)
                    return SVGPatternNode(node);
            }
            return null;
        }

        /**
         * Getters / Setters
        **/
        public function set xml(xml:XML):void {
            _xml = xml;

            this.clearChildren();

            if (_xml) {
                this._parsedChildren = false;
                this.parseStyle();
                this.invalidateDisplay();
            }

            this.updateClones();
        }
        
        public function get xml():XML {
            return this._xml;
        }

        public function get id():String {
            var id:String = this._xml.@id;
            return id;
        }

        public function get invalidDisplay():Boolean {
            return this._invalidDisplay;
        }


        public function dbg(debugString:String):void {
            if (this.svgRoot) {
                this.svgRoot.debug(debugString);
            }
        }
        
        public function err(errorString:String):void {
            if (this.svgRoot) {
                this.svgRoot.error(errorString);
            }
        }
    }
}