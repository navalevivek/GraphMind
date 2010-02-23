package com.graphmind.display
{
	import com.graphmind.ConnectionManager;
	import com.graphmind.GraphMindManager;
	import com.graphmind.PluginManager;
	import com.graphmind.StageManager;
	import com.graphmind.data.NodeItemData;
	import com.graphmind.event.NodeEvent;
	import com.graphmind.temp.TempItemLoadData;
	import com.graphmind.util.Log;
	import com.graphmind.util.StringUtility;
	
	import components.ItemBaseComponent;
	
	import flash.display.Sprite;
	import flash.events.ContextMenuEvent;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.Keyboard;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Image;
	import mx.core.UIComponent;
	import mx.events.FlexEvent;
	
	public class NodeItem extends UIComponent implements ITreeNode {
		
		public static const WIDTH_MC_DEFAULT:int = 168;
		public static const WIDTH_DEFAULT:int = 162;
		public static const HEIGHT:int = 20;
		public static const ICON_WIDTH:int = 18;
		[Bindable]
		public static var TITLE_DEFAULT_WIDTH:int = 120;
		public static var TITLE_MAX_WIDTH:int = 220;
		[Bindable]
		public static var ICON_ADD_DEFAULT_X:int = 140;
		[Bindable]
		public static var ICON_ANCHOR_DEFAULT_X:int = 122;
		[Bindable]
		public static var ICON_BULLET_DEFAULT_X:int = WIDTH_DEFAULT - 4;
		[Bindable]
		public static var ICON_INSERT_LEFT_DEFAULT_X:int = WIDTH_DEFAULT - 2;
		
		private static const EFFECT_NORMAL:int = 0;
		private static const EFFECT_HIGHLIGHT:int = 1;
		
		// Node access caches
		public static var nodes:ArrayCollection = new ArrayCollection();
		
		public static const HOOK_NODE_CONTEXT_MENU:String  = 'node_context_menu';
		public static const HOOK_NODE_MOVED:String         = 'node_moved';
		public static const HOOK_NODE_DELETE:String		   = 'node_delete';
		public static const HOOK_NODE_CREATED:String	   = 'node_created';
		public static const HOOK_NODE_TITLE_CHANGED:String = 'node_title_changed';
		
		protected var _displayComp:ItemBaseComponent = new ItemBaseComponent();
		protected var _nodeItemData:NodeItemData;
		protected var _childs:ArrayCollection 		 = new ArrayCollection();
		protected var _isCollapsed:Boolean 		 	 = false;
		protected var _isForcedCollapsed:Boolean 	 = false;
		protected var _parentNode:NodeItem 			 = null;
		protected var _backgroundComp:Sprite 		 = new Sprite();
		protected var _hasPath:Boolean 				 = false;
		protected var _icons:ArrayCollection		 = new ArrayCollection();
		protected var _isCloud:Boolean				 = false;
		
		// Display effects
		private static var _nodeDropShadow:DropShadowFilter = new DropShadowFilter(1, 45, 0x888888, 1, 1, 1);
		private static var _nodeGlowFilter:GlowFilter = new GlowFilter(0x0072B9, .8, 6, 6);
		private static var _nodeInnerGlowFilter:GlowFilter = new GlowFilter(0xFFFFFF, .8, 20, 20, 2, 1, true);
		
		// ArrowLinks
		private var _arrowLinks:ArrayCollection = new ArrayCollection(); 
		
		
		private var _mouseSelectionTimeout:uint;

		/**
		 * Constructor
		 */
		public function NodeItem(viewItem:NodeItemData) {
			// Init super class
			super();
			NodeItem.nodes.addItem(this);
			// Attach data object
			this._nodeItemData = viewItem;
			// Init display elements
			_initDisplayElements();
			// Init events
			_initAttachEvents();
			
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.CREATED, this));
		}
		
		private function _initDisplayElements():void {
			// Context menu 
			if (GraphMindManager.getInstance().isEditable()) {
				_initCreateContextMenu();
			}
			
			this.addChild(_backgroundComp);
			
			this.addChild(_displayComp);
			
			this._displayComp.title_label.htmlText = this._nodeItemData.title;
		
			_hasPath = _nodeItemData.getPath().length > 0;
			
			this.buttonMode = true;
			
			this.redrawNodeBody();
		}
			
		private function _initAttachEvents():void {
			if (GraphMindManager.getInstance().isEditable()) {
				this._displayComp.title_label.doubleClickEnabled = true;
				this._displayComp.title_label.addEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClick);
				
				this._displayComp.title_new.addEventListener(KeyboardEvent.KEY_UP, onKeyUp_TitleTextField);
				this._displayComp.title_new.addEventListener(FocusEvent.FOCUS_OUT, onFocusOut_TitleTextField);
				
				this._displayComp.icon_add.addEventListener(MouseEvent.CLICK, onClick_AddSimpleNodeButton);
				
				this._displayComp.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
				this._displayComp.addEventListener(MouseEvent.MOUSE_UP,   onMouseUp);
				this._displayComp.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			}
			
			this._displayComp.addEventListener(MouseEvent.CLICK, onClick);
			this._displayComp.addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
			this._displayComp.addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
			
			this._displayComp.title_label.addEventListener(FlexEvent.UPDATE_COMPLETE, onUpdateComplete_TitleLabel);
			
			this._displayComp.icon_anchor.addEventListener(MouseEvent.CLICK, onClick_NodeLinkButton);
			this._displayComp.icon_has_child.addEventListener(MouseEvent.CLICK, onClick_ToggleSubtreeButton);
		}

		private function _initCreateContextMenu():void {
			var contextMenu:ContextMenu = new ContextMenu();
			contextMenu.customItems = [];
			contextMenu.hideBuiltInItems();
			
			var cms:Array = [
				{title: 'Add node',        event: onContextMenuSelected_AddSimpleNode,    separator: false},
				{title: 'Add Drupal item', event: onContextMenuSelected_AddDrupalItem, 	 separator: false},
				{title: 'Add Views list',  event: onContextMenuSelected_AddDrupalViews,   separator: false},
				{title: 'Remove node',     event: onContextMenuSelected_RemoveNode,       separator: true},
				{title: 'Remove childs',   event: onContextMenuSelected_RemoveNodeChilds, separator: false},
				{title: 'Open subtree',    event: onContextMenuSelected_OpenSubtree,      separator: true},
				{title: 'Toggle cloud',    event: onContextMenuSelected_ToggleCloud,      separator: false}
			];
			
			if (NodeItemData.updatableTypes.indexOf(_nodeItemData.type) >= 0) {
				cms.push({title: 'Update node', event: onContextMenuSelected_UpdateDrupalItem, separator: false});
			}
			
			// Extend context menu items by Plugin provided menu items
			PluginManager.callHook(HOOK_NODE_CONTEXT_MENU, {data: cms});
			Log.debug('contextmenu: ' + cms.length);
			
			for each (var cmData:Object in cms) {
				var cmi:ContextMenuItem = new ContextMenuItem(cmData.title,	cmData.separator);
				cmi.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, function(_event:ContextMenuEvent):void {
					selectNode();
				});
				cmi.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, cmData.event);
				contextMenu.customItems.push(cmi);
			}
			
			_displayComp.contextMenu = contextMenu;
		}
		
		private function onMouseDown(event:MouseEvent):void {
			StageManager.getInstance().prepaireDragAndDrop();
			event.stopImmediatePropagation();
		}
		
		private function onMouseUp(event:MouseEvent):void {
			if ((!StageManager.getInstance().isPrepairedNodeDragAndDrop) && StageManager.getInstance().isNodeDragAndDrop) {
				
				if (this.mouseX / this.getWidth() > (1 - this.mouseY / HEIGHT)) {
					NodeItem.move(StageManager.getInstance().dragAndDrop_sourceNode, this);
				} else {
					NodeItem.moveToPrevSibling(StageManager.getInstance().dragAndDrop_sourceNode, this);
				}
				StageManager.getInstance().onMouseUp_MindmapStage();
				
				_displayComp.insertLeft.visible = false;
				_displayComp.insertUp.visible = false;
			}
		}
		
		private function onMouseMove(event:MouseEvent):void {
			if ((!StageManager.getInstance().isPrepairedNodeDragAndDrop) && StageManager.getInstance().isNodeDragAndDrop) {
				if (this.mouseX / this.getWidth() > (1 - this.mouseY / HEIGHT)) {
					_displayComp.insertLeft.visible = true;
					_displayComp.insertUp.visible = false;
				} else {
					_displayComp.insertLeft.visible = false;
					_displayComp.insertUp.visible = true;
				}
			}
		}
		
		private function onContextMenuSelected_AddSimpleNode(event:ContextMenuEvent):void {
			addSimpleChildNode();
		}
		
		private function onContextMenuSelected_AddDrupalItem(event:ContextMenuEvent):void {
			loadItem();
		}
		
		private function onContextMenuSelected_AddDrupalViews(event:ContextMenuEvent):void {
			loadViews();
		}
		
		private function onContextMenuSelected_RemoveNode(event:ContextMenuEvent):void {
			kill();
		}
		
		private function onContextMenuSelected_RemoveNodeChilds(event:ContextMenuEvent):void {
			_removeNodeChilds();
		}
		
		private function onClick(event:MouseEvent):void {
		}
		
		private function onClick_ToggleSubtreeButton(event:MouseEvent):void {
			if (!this._isCollapsed) {
				collapse();
			} else {
				uncollapse();
			}
			StageManager.getInstance().setMindmapUpdated();
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
			event.stopPropagation();
		}
		
		private function onMouseOver(event:MouseEvent):void {
			_mouseSelectionTimeout = setTimeout(selectNode, 400);
			_displayComp.icon_add.visible = true && GraphMindManager.getInstance().isEditable();
			_displayComp.icon_anchor.visible = true && _hasPath;
		}
		
		private function onMouseOut(event:MouseEvent):void {
			clearTimeout(_mouseSelectionTimeout);
			_displayComp.icon_add.visible = false;
			_displayComp.icon_anchor.visible = false;
			
			if (StageManager.getInstance().isPrepairedNodeDragAndDrop) {
				StageManager.getInstance().openDragAndDrop(this);
			}
			
			_displayComp.insertLeft.visible = false;
			_displayComp.insertUp.visible = false;
		}
		
		private function onDoubleClick(event:MouseEvent):void {
			_displayComp.currentState = 'edit_title';
			_displayComp.title_new.text = _displayComp.title_label.text;
			_displayComp.title_new.setFocus();
		}
		
		private function onKeyUp_TitleTextField(event:KeyboardEvent):void {
			if (event.keyCode == Keyboard.ENTER) {
				_displayComp.currentState = '';
				setTitle(_displayComp.title_new.text);
				GraphMind.instance.setFocus();
				selectNode();
			} else if (event.keyCode == Keyboard.ESCAPE) {
				_displayComp.currentState = '';
				_displayComp.title_new.text = _displayComp.title_label.text;
			}
		}
		
		private function onFocusOut_TitleTextField(event:FocusEvent):void {
			// @TODO this is a duplication of the onNewTitleKeyUp() (above)
			_displayComp.currentState = '';
			_nodeItemData.title = _displayComp.title_label.text = _displayComp.title_new.text;
			GraphMind.instance.setFocus();
		}
		
		private function onItemLoaderSelectorClick(event:MouseEvent):void {
			event.stopPropagation();
			selectNode();
			GraphMind.instance.panelLoadView.view_arguments.text = _nodeItemData.getDrupalID();
		}
		
		private function onClick_AddSimpleNodeButton(event:MouseEvent):void {
			event.stopPropagation();
			event.stopImmediatePropagation();
			event.preventDefault();
			addSimpleChildNode();
		}
		
		private function onLoadItemClick(event:MouseEvent):void {
			event.stopPropagation();
			loadItem();
		}
		
		private function onLoadViewClick(event:MouseEvent):void {
			event.stopPropagation();
			loadViews();
		}
		
		private function onClick_NodeLinkButton(event:MouseEvent):void {
			var ur:URLRequest = new URLRequest(_nodeItemData.getPath());
			navigateToURL(ur, '_blank');
		}
		
		public function getChildNodeAll():ArrayCollection {
			return _childs;
		}
		
		public function getChildNodeAt(index:int):ITreeNode {
			return _childs.getItemAt(index) as ITreeNode;
		}
		
		public function getChildNodeIndex(child:ITreeNode):int {
			return _childs.getItemIndex(child);
		}
		
		public function removeChildNodeAll():void {
			_childs.removeAll();
		}
		
		public function removeChildNodeAt(index:int):void {
			_childs.removeItemAt(index);
		}
		
		public function addChildNodeWithStageRefresh(node:NodeItem):void {
			addChildNode(node);
			
			// Add UI to the stage
			StageManager.getInstance().addNodeToStage(node as NodeItem);
		}
		
		/**
		 * Add a new child node to the node
		 */
		public function addChildNode(node:ITreeNode):void {
			// Add node as a new child
			this._childs.addItem(node);
			(node as NodeItem)._parentNode = this;
			
			// Open subtree.
			this.uncollapseChilds();
			// Showing toggle-subtree button.
			this._displayComp.icon_has_child.visible = true;
			
			// Not necessary to fire NODE_ATTCHED event. MOVED and CREATED covers this.
		}
		
		public function collapse():void {
			_isForcedCollapsed = true;
			collapseChilds();
		}
		
		public function collapseChilds():void {
			_isCollapsed = true;
			_displayComp.icon_has_child.source = _displayComp.image_node_uncollapse;
			for each (var nodeItem:NodeItem in _childs) {
				nodeItem.visible = false;
				nodeItem.collapseChilds();
			}
			StageManager.getInstance().setMindmapUpdated();
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
		}
		
		public function uncollapse():void {
			_isForcedCollapsed = false;
			uncollapseChilds();
		}
		
		public function uncollapseChilds(forceOpenSubtree:Boolean = false):void {
			_isCollapsed = false;
			_displayComp.icon_has_child.source = _displayComp.image_node_collapse;
			for each (var nodeItem:NodeItem in _childs) {
				nodeItem.visible = true;
				if (!nodeItem._isForcedCollapsed || forceOpenSubtree) {
					nodeItem.uncollapseChilds(forceOpenSubtree);
				}
			}
			StageManager.getInstance().setMindmapUpdated();
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
		}
		
		private function getTypeColor():uint {
			if (_nodeItemData.color) {
				return _nodeItemData.color;
			}
			
			switch (this._nodeItemData.type) {
				case NodeItemData.NODE:
					return 0xC2D7EF;
				case NodeItemData.COMMENT:
					return 0xC2EFD9;
				case NodeItemData.USER:
					return 0xEFD2C2;
				case NodeItemData.FILE:
					return 0xE9C2EF;
				case NodeItemData.TERM:
					return 0xD9EFC2;
				default:
					return 0xDFD9D1;
			}
		}
		
		/**
		 * Select a single node on the mindmap stage.
		 * Only one node can be active at a time.
		 * Accessing to this node: StageManager.getInstance().activeNode():NodeItem.
		 */
		public function selectNode():void {
			var isTheSameSelected:Boolean = isSelected();
			
			// Not to lose focus from textfield
			if (!isTheSameSelected) setFocus();
			
			// @TODO mystery bug steal highlight somethimes from nodes
			if (StageManager.getInstance().activeNode) {
				StageManager.getInstance().activeNode.unselectNode();
			}
			StageManager.getInstance().activeNode = this;
			StageManager.getInstance().selectedNodeData = new ArrayCollection();
			for (var key:* in _nodeItemData.data) {
				StageManager.getInstance().selectedNodeData.addItem({
					key: key,
					value: _nodeItemData.data[key]
				});
			}
			
			GraphMind.instance.mindmapToolsPanel.node_info_panel.nodeLabelRTE.htmlText = _displayComp.title_label.htmlText || _displayComp.title_label.text;
				
			if (!isTheSameSelected) {
				GraphMind.instance.mindmapToolsPanel.node_info_panel.link.text = _nodeItemData.getPath();
				GraphMind.instance.mindmapToolsPanel.node_attributes_panel.attributes_update_param.text = '';
				GraphMind.instance.mindmapToolsPanel.node_attributes_panel.attributes_update_value.text = '';
			}
				
			_setBackgroundEffect(EFFECT_HIGHLIGHT);
		}
		
		public function unselectNode():void {
			_setBackgroundEffect(EFFECT_NORMAL);
		}
		
		public function exportToFreeMindFormat():String {
			//var titleIsHTML:Boolean = _displayComponent.title_label.text != _displayComponent.title_label.htmlText;
			var titleIsHTML:Boolean = _nodeItemData.title.toString().indexOf('<') >= 0;
			
			// Base node information
			var output:String = '<node ' + 
				'CREATED="'  + _nodeItemData.created   + '" ' + 
				'MODIFIED="' + _nodeItemData.modified  + '" ' + 
				'ID="'       + _nodeItemData.id        + '" ' + 
				'FOLDED="'   + (_isForcedCollapsed ? 'true' : 'false') + '" ' + 
				(titleIsHTML ? '' : 'TEXT="' + escape(_nodeItemData.title) + '" ') + 
				(_nodeItemData.getPath().toString().length > 0 ? ('LINK="' + escape(_nodeItemData.getPath()) + '" ') : '') + 
				'TYPE="' + _nodeItemData.type + '" ' +
				">\n";
			
			if (titleIsHTML) {
				output = output + "<richcontent TYPE=\"NODE\"><html><head></head><body>" + 
					_nodeItemData.title + 
					"</body></html></richcontent>";
			}
			
			var key:*;
			for (key in _nodeItemData.data) {
				output = output + '<attribute NAME="' + escape(key) + '" VALUE="' + escape(_nodeItemData.data[key]) + '"/>' + "\n";
			}
			
			if (_nodeItemData.source) {
				output = output + '<site URL="' + escape(_nodeItemData.source.url) + '" USERNAME="' + escape(_nodeItemData.source.username) + '"/>' + "\n";
			}
			
			for each (var icon:* in _icons) {
				output = output + '<icon BUILTIN="' + StringUtility.iconUrlToIconName((icon as Image).source.toString()) + '"/>' + "\n";
			}
			
			if (_isCloud) {
				output = output + '<cloud/>' + "\n";
			}
			
			// Add childs
			for each (var child:NodeItem in _childs) {
				output = output + child.exportToFreeMindFormat();
			}
			
			return output + '</node>' + "\n";
		}
		
		public function getNodeData():Object {
			return _nodeItemData.data;
		}
		
		private function loadItem():void {
			selectNode();
			GraphMind.instance.currentState = 'load_item_state';
		}
		
		private function loadViews():void {
			selectNode();
			GraphMind.instance.currentState = 'load_view_state';
			GraphMind.instance.panelLoadView.view_arguments.text = _nodeItemData.getDrupalID();
		}
		
		private function addSimpleChildNode():void {
			selectNode();
			StageManager.getInstance().createSimpleChildNode(this);
		}
		
		/**
		 * Remove each child of the node.
		 */
		private function _removeNodeChilds():void {
			while (_childs.length > 0) {
				(_childs.getItemAt(0) as NodeItem).kill();
			}
		}
		
		/**
		 * Kill a node and each childs.
		 */
		private function kill():void {
			if (StageManager.getInstance().baseNode === this) return;
			
			// @HOOK
			PluginManager.callHook(HOOK_NODE_DELETE, {node: this});
			
			// Remove all children the same way.
			_removeNodeChilds();
			
			if (_parentNode) {
				// Remove parent's child (this child).
				_parentNode._childs.removeItemAt(_parentNode._childs.getItemIndex(this));
				// Check parent's toggle-subtree button. With no child it should be hidden.
				_parentNode._displayComp.icon_has_child.visible = _parentNode._childs.length > 0;
			}
			// Remove main UI element.
			_displayComp.parent.removeChild(_displayComp);
			// Remove the whole UI.
			parent.removeChild(this);
			
			// Remove event listeners
			this._displayComp.title_label.removeEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClick);
			this._displayComp.title_new.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp_TitleTextField);
			this._displayComp.title_new.removeEventListener(FocusEvent.FOCUS_OUT, onFocusOut_TitleTextField);
			this._displayComp.icon_add.removeEventListener(MouseEvent.CLICK, onClick_AddSimpleNodeButton);
			this._displayComp.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			this._displayComp.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			this._displayComp.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			this._displayComp.removeEventListener(MouseEvent.CLICK, onClick);
			this._displayComp.removeEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
			this._displayComp.removeEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
			this._displayComp.title_label.removeEventListener(FlexEvent.UPDATE_COMPLETE, onUpdateComplete_TitleLabel);
			this._displayComp.icon_anchor.removeEventListener(MouseEvent.CLICK, onClick_NodeLinkButton);
			this._displayComp.icon_has_child.removeEventListener(MouseEvent.CLICK, onClick_ToggleSubtreeButton);
			
			// Remove from the global storage
			nodes.removeItemAt(nodes.getItemIndex(this));
			
			// Update tree.
			StageManager.getInstance().setMindmapUpdated();
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
			
			delete this; // :.(
		}
		
		public function addData(attribute:String, value:String):void {
			_nodeItemData.dataAdd(attribute, value);
			StageManager.getInstance().setMindmapUpdated();
			updateTime();
		}
		
		public function deleteData(param:String):void {
			_nodeItemData.dataDelete(param);
			StageManager.getInstance().setMindmapUpdated();
			updateTime();
		}
		
		public function isChild(node:NodeItem):Boolean {
			for each (var child:NodeItem in _childs) {
				if (child == node) {
					return true;
				}
				if (child.isChild(node)) return true;
			}
			
			return false;
		}
		
		public static function move(source:NodeItem, target:NodeItem, callEvent:Boolean = true):Boolean {
			// No parent can detach child.
			if (!source || !source._parentNode || !target) return false;
			// Target is an ascendant of the source.
			if (source.isChild(target)) return false;
			// Source is equal to target
			if (source == target) return false;
			
			// Remove source from parents childs
			source.removeFromParentsChilds();
			// Add source to target
			target.addChildNode(source);
			// Refresh display
			StageManager.getInstance().setMindmapUpdated();
			// Calling event with the value of NULL indicates that a full update is needed.
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS));
			
			if (callEvent) {
				// Call hook
				PluginManager.callHook(HOOK_NODE_MOVED, {node: source});
				StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.MOVED, source));
			}
			
			return true;
		}
		
		public static function moveToPrevSibling(source:NodeItem, target:NodeItem):void {
			if (move(source, target._parentNode, false)) {
				var siblingIDX:int = target._parentNode._childs.getItemIndex(target);
				if (siblingIDX == -1) {
					return;
				}
				
				for (var i:int = target._parentNode._childs.length - 1; i > siblingIDX; i--) {
					target._parentNode._childs[i] = target._parentNode._childs[i - 1];
				}
				
				target._parentNode._childs.setItemAt(source, siblingIDX);
				
				// Refresh after reordering
				StageManager.getInstance().setMindmapUpdated();
				StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS));
				
				// Call hook
				PluginManager.callHook(HOOK_NODE_MOVED, {node: source});
				StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.MOVED, source));
			}
		}
		
		private function removeFromParentsChilds():void {
			// Fix source's old parent's has_child icon
			var parentNode:NodeItem = _parentNode;
			
			var childIDX:int = _parentNode._childs.getItemIndex(this);
			if (childIDX >= 0) {
				this._parentNode._childs.removeItemAt(childIDX);
			}
			
			parentNode._displayComp.icon_has_child.visible = parentNode._childs.length > 0;
		}
		
		public function addIcon(source:String):void {
			// Icon is already exists
			for each (var ico:Image in _icons) {
				if (ico.source == source) return;
			}
			
			// Getting the normal icon name only
			var iconName:String = StringUtility.iconUrlToIconName(source);
			
			var icon:Image = new Image();
			icon.source = source;
			icon.y = 2;
			_displayComp.addChild(icon);
			_icons.addItem(icon);
			if (GraphMindManager.getInstance().isEditable()) {
				icon.doubleClickEnabled = true;
				icon.addEventListener(MouseEvent.DOUBLE_CLICK, removeIcon);
			}
		
			redrawNodeBody();
			redrawParentsClouds();
			
			updateTime();
 		}
 		
 		public function removeIcon(event:MouseEvent):void {
 			var iconIDX:int = _icons.getItemIndex(event.currentTarget as Image);
 			if (iconIDX == -1) return;
 			_icons.removeItemAt(iconIDX);
 			_displayComp.removeChild(event.currentTarget as Image);
 			redrawNodeBody();
 			redrawParentsClouds();
 			
 			updateTime();
 		}
 		
 		public function redrawNodeBody():void {
 			var titleExtraWidth:int = _getTitleExtraWidth();
 			for (var idx:* in _icons) {
 				Image(_icons[idx]).x = titleExtraWidth + ICON_WIDTH * idx + 158;
 			}
 			
 			var leftOffset:int = _getIconsExtraWidth() + titleExtraWidth;
 				
 			this._backgroundComp.graphics.clear();		
			this._backgroundComp.graphics.beginFill(getTypeColor());
			this._backgroundComp.graphics.drawRoundRect(0, 0, WIDTH_DEFAULT + leftOffset, HEIGHT, 10, 10);
			this._backgroundComp.graphics.endFill();
			
			_setBackgroundEffect(isSelected() ? EFFECT_HIGHLIGHT : EFFECT_NORMAL);
			
			this._displayComp.width = WIDTH_MC_DEFAULT + leftOffset;
			this._displayComp.icon_has_child.x = ICON_BULLET_DEFAULT_X + leftOffset;
			this._displayComp.insertLeft.x = ICON_INSERT_LEFT_DEFAULT_X + leftOffset;
			this._displayComp.title_label.width = TITLE_DEFAULT_WIDTH + titleExtraWidth;
			this._displayComp.icon_add.x = ICON_ADD_DEFAULT_X + titleExtraWidth;
			this._displayComp.icon_anchor.x = ICON_ANCHOR_DEFAULT_X  + titleExtraWidth;
			
			// @TODO refreshing subtree is enough
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
 		}
		
		public function setTitle(title:String):void {
			_nodeItemData.title = _displayComp.title_label.htmlText = title;
			PluginManager.callHook(HOOK_NODE_TITLE_CHANGED, {node: this});
			updateTime();
		}
		
		public function onUpdateComplete_TitleLabel(event:FlexEvent):void {
			redrawNodeBody();
			// @TODO refreshing subtree is enough
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
			redrawParentsClouds();
		}
		
		public function setLink(link:String):void {
			_nodeItemData.link = link;
			_displayComp.icon_anchor.visible = _hasPath = link.length > 0;
			updateTime();
			StageManager.getInstance().setMindmapUpdated();
		}
		
		/**
		 * Upadte node's time.
		 * Reasons:
		 *  - modified title
		 *  - changed attributes
		 *  - toggled cloud
		 */
		public function updateTime():void {
			_nodeItemData.modified = (new Date()).time;
		}
		
		public function onContextMenuSelected_OpenSubtree(event:ContextMenuEvent):void {
			uncollapseChilds(true);
		}
		
		public function toggleCloud(forceRedraw:Boolean = false):void {
			_isCloud = !_isCloud;
			
			StageManager.getInstance().setMindmapUpdated();
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
		}
		
		public function onContextMenuSelected_ToggleCloud(event:ContextMenuEvent):void {
			toggleCloud(true);
			updateTime();
		}
		
		public function getBoundingPoints():Array {
			// Top-left - top-right - bottom-right - bottom-left.
			return [
				[x, y],
				[x + getWidth(), y],
				[x + getWidth(), y + getHeight()],
				[x, y + getHeight()]
			];
		}
		
		/**
		 * Refresh only the subtree and redraw the stage.
		 */
		public function redrawParentsClouds():void {
			_redrawParentsClouds();
			StageManager.getInstance().dispatchEvent(new NodeEvent(NodeEvent.UPDATE_GRAPHICS, this));
		}
		
		private function _redrawParentsClouds():void {
			if (_isCloud) {
				toggleCloud();
				toggleCloud();
			}
			
			if (_parentNode) _parentNode._redrawParentsClouds();
		}
		
		public function isSelected():Boolean {
			return StageManager.getInstance().activeNode == this;
		}
		
		public function isCollapsed():Boolean {
			return _isCollapsed;
		}
	
		public function onContextMenuSelected_UpdateDrupalItem(event:ContextMenuEvent):void {
			updateDrupalItem();
		}
		
		public function updateDrupalItem():void {
			var tild:TempItemLoadData = new TempItemLoadData();
			tild.nodeItemData = _nodeItemData;
			tild.success = updateDrupalItem_result;
			ConnectionManager.getInstance().itemLoad(tild);
		}
		
		public function updateDrupalItem_result(result:Object, tild:TempItemLoadData):void {
			for (var key:* in result) {
				_nodeItemData.data[key] = result[key];
			}
			_nodeItemData.title = null;
			_updateTitleLabel();
			selectNode();
		}
		
		private function _updateTitleLabel():void {
			_displayComp.title_label.text = _nodeItemData.title;
		}
		
		private function _setBackgroundEffect(effect:int = EFFECT_NORMAL):void {
			_backgroundComp.filters = (effect == EFFECT_NORMAL) ? [_nodeDropShadow] : [_nodeInnerGlowFilter, _nodeGlowFilter];
		}
		
		public function getEqualChild(data:Object, type:String):NodeItem {
			for each (var child:NodeItem in _childs) {
				if (child._nodeItemData.equalTo(data, type)) return child;
			}
			return null;
		}
		
		public static function getLastSelectedNode():NodeItem {
			return StageManager.getInstance().activeNode;
		}
		
		public function getParentNode():ITreeNode {
			return _parentNode;
		}
		
		public function get nodeItemData():NodeItemData {
			return _nodeItemData;
		}
		
		public function getTitle():String {
			return _nodeItemData.title;
		}
		
		public function isHasCloud():Boolean {
			return _isCloud;
		}
		
		public function getHeight():int {
			return HEIGHT;
		}
		
		public function getWidth():int {
			return WIDTH_DEFAULT + _getIconsExtraWidth() + _getTitleExtraWidth(); 
		}
		
		private function _getTitleExtraWidth():int {
			return _displayComp.title_label.measuredWidth <= TITLE_DEFAULT_WIDTH ? 
				0 :
				(_displayComp.title_label.measuredWidth >= TITLE_MAX_WIDTH ? 
					TITLE_MAX_WIDTH - TITLE_DEFAULT_WIDTH :
					_displayComp.title_label.measuredWidth - TITLE_DEFAULT_WIDTH);
		}
		
		private function _getIconsExtraWidth():int {
			return _icons.length * ICON_WIDTH;
		}
		
		public function getArrowLinks():ArrayCollection {
			return _arrowLinks;
		}
		
		public function addArrowLink(arrowLink:ArrowLink):void {
			this._arrowLinks.addItem(arrowLink);
		}
		
		public override function toString():String {
			return '[Node: ' + this._nodeItemData.id + ']';
		}
		
	}
}