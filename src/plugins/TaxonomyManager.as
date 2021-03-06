package plugins {
	
	import com.graphmind.ConnectionController;
	import com.graphmind.NodeViewController;
	import com.graphmind.data.NodeDataObject;
	import com.graphmind.data.NodeType;
	import com.graphmind.event.EventCenter;
	import com.graphmind.event.EventCenterEvent;
	import com.graphmind.util.Log;
	import com.graphmind.util.OSD;
	
	import flash.events.ContextMenuEvent;
	

	public class TaxonomyManager {
		
		/**
		 * Node type for vocabularies.
		 */
		public static const TAXONOMY_MANAGER_NODE_VOCABULARY_TYPE:String = 'vocabulary';
		
		/**
		 * Colors for node types.
		 */
		public static const TAXONOMY_MANAGER_NODE_VOCABULARY_COLOR:uint = 0xEF95E7;
		public static const TAXONOMY_MANAGER_NODE_TERM_COLOR:uint       = 0xDFC3DC;
		
		/**
		 * Flag that prevents node deletion/rename on vocabulary refresh.
		 */
		public static var lockUpdateFlag:Boolean = true;
		
		
		/**
		 * Implementation of init().
		 */
		public static function init():void {
			EventCenter.subscribe(EventCenterEvent.MAP_TREE_IS_COMPLETE, onMapTreeIsComplete);
			EventCenter.subscribe(EventCenterEvent.NODE_DID_ADDED_TO_PARENT, onNodeDidAddedToParent);
			EventCenter.subscribe(EventCenterEvent.NODE_DID_MOVED, onNodeDidMoved);
			EventCenter.subscribe(EventCenterEvent.NODE_IS_KILLED, onNodeIsKilled);
			EventCenter.subscribe(EventCenterEvent.NODE_TITLE_CHANGED, onNodeTitleChanged);
		}
		
		
		/**
		 * Handler when the initial map is on the ui and ready to examine.
		 */
		private static function onMapTreeIsComplete(event:EventCenterEvent):void {
			// Refreshing taxonomy
			lockUpdateFlag = true;
			
			var cursor:int = 0;
			var parent:NodeViewController = null;
			while (NodeViewController.nodes.length > cursor) {
				var node:NodeViewController = NodeViewController.nodes[cursor] as NodeViewController;
				if (_isTaxonomyPluginNode(node, TAXONOMY_MANAGER_NODE_VOCABULARY_TYPE)) {
					parent = node.getParentNode() as NodeViewController;
					node.kill();
					cursor = 0;
				} else {
					cursor++;
				}
			}
			
			if (parent !== null) {
				parent.select();
				loadFullTaxonomyTree(null);
			}
		} 
		
		
		/**
		 * Implementation of hook_node_context_menu_alter().
		 */
		public static function alter_context_menu(cm:Array):void {
			cm.push({title: 'Load taxonomy', event: TaxonomyManager.loadFullTaxonomyTree, separator: true});
		}
		
		
		/**
		 * Callback for loading and attaching taxonomy tree.
		 */
		public static function loadFullTaxonomyTree(event:ContextMenuEvent):void {
		  lockUpdateFlag = true;
		  
			var node:NodeViewController = NodeViewController.activeNode;
			ConnectionController.mainConnection.call(
			  'graphmindTaxonomyManager.getAll',
			  function(_event:Object):void {
          onSuccess_TaxonomyRequestReady(_event, node);
        },
        transactionError
      );
		}
		
		
		/**
		 * Success event callback for the taxonomy loading.
		 */
		private static function onSuccess_TaxonomyRequestReady(event:Object, baseNode:NodeViewController):void {
			for each (var vocabulary:Object in event) {
				vocabulary.plugin = 'TaxonomyManager';
				var vocabularyNode:NodeViewController = new NodeViewController(new NodeDataObject(vocabulary, TAXONOMY_MANAGER_NODE_VOCABULARY_TYPE, ConnectionController.mainConnection));
        vocabularyNode.setTitle(vocabulary.name);
        vocabularyNode.setColor(TAXONOMY_MANAGER_NODE_VOCABULARY_COLOR);
        baseNode.addChildNode(vocabularyNode);
				
				var term_hierarchy:Object = {};
				var term_storage:Object = {0: vocabularyNode};
				
				for each (var term:Object in vocabulary.terms) {
					term.plugin = 'TaxonomyManager';
					var termNodeItem:NodeViewController = new NodeViewController(new NodeDataObject(term, NodeType.TERM, ConnectionController.mainConnection));
					termNodeItem.setTitle(term.name);
					termNodeItem.setColor(TAXONOMY_MANAGER_NODE_TERM_COLOR);
					
					var parentID:String = term.parents[0] || 'none';
					if (!term_hierarchy.hasOwnProperty(parentID)) {
						term_hierarchy[parentID] = [];
					}
					(term_hierarchy[parentID] as Array).push(termNodeItem);
					term_storage[term.tid] = termNodeItem;
				}
				
				for (var _parentID:* in term_hierarchy) {
					for each (var termNode:NodeViewController in term_hierarchy[_parentID]) {
						(term_storage[_parentID] as NodeViewController).addChildNode(termNode);
					}
				}
			}
			OSD.show('Taxonomy tree is loaded.');
			
      lockUpdateFlag = false;
		}
		
		
		/**
		 * Implementation of hook_node_moved.
		 */
		public static function onNodeDidMoved(event:EventCenterEvent):void {
			var node:NodeViewController = event.data as NodeViewController;
			
			// Node is not a TERM.
			if (!_isTaxonomyPluginNode(node, NodeType.TERM)) {
				return;
			}
			
 			var parentNode:NodeViewController = node.getParentNode() as NodeViewController;
			
			// Deleting term
			if (!_isTaxonomyPluginNode(parentNode)) {
				onNodeIsKilled(event);
				_removePluginInfoFromNode(node);
				return;
			}

			var order:Array = [];
			for each (var child:NodeViewController in parentNode.getChildNodeAll()) {
				if (child.nodeData.drupalData.hasOwnProperty('tid')) {
					order.push(child.nodeData.drupalData.tid);
				}
			}
			
			var childNodes:Array = _changeChildsVocabulary(node, parentNode.nodeData.drupalData.vid || 0);
			_changeSiblingsWeight(node);
			
			ConnectionController.mainConnection.call(
			  'graphmindTaxonomyManager.moveTerm',
			  function(_event:Object):void{
          OSD.show('Term\'s new position is saved.');
        },
			  transactionError,
        node.nodeData.drupalData.tid,
        parentNode.nodeData.drupalData.vid || 0,
        parentNode.nodeData.drupalData.tid || 0,
        order.join('|'),
        childNodes.join('|')
      );
		}


		/**
		 * Check if the node created by the TaxonomyManager plugin and has a certain type.
		 */
		private static function _isTaxonomyPluginNode(node:NodeViewController, type:String = null):Boolean {
			if (!node.nodeData.drupalData.hasOwnProperty('plugin') || node.nodeData.drupalData.plugin !== 'TaxonomyManager') {
				return false;
			}
			return type == null ? true : node.nodeData.type == type;
		}
		
		
		/**
		 * Change the subtree's VID to a given value.
		 * If a node moved to another vocabulary, all subterms should be adopted.
		 * 
		 * @param NodeItem node
		 * @param integer vid
		 */
		private static function _changeChildsVocabulary(node:NodeViewController, vid:int):Array {
			node.nodeData.drupalData.vid = vid;
			
			var nodes:Array = [node.nodeData.drupalData.tid || 0];
			for each (var child:NodeViewController in node.getChildNodeAll()) {
				nodes = nodes.concat(_changeChildsVocabulary(child, vid));
			}
			
			return nodes;
		}
		
		
		/**
		 * Recount weight values of a term's siblings
		 * 
		 * @param NodeItem node
		 */
		private static function _changeSiblingsWeight(node:NodeViewController):void {
			var parentNode:NodeViewController = node.getParentNode() as NodeViewController;
			var weight:int = 0;
			for each (var child:NodeViewController in parentNode.getChildNodeAll()) {
				child.nodeData.drupalData.weight = weight++;
			}
		}
		
		
		/**
		 * Implementation of hook_node_delete().
		 * 
		 * @param Object data
		 */
		public static function onNodeIsKilled(event:EventCenterEvent):void {
		  if (lockUpdateFlag) return;
			
			var node:NodeViewController = event.data as NodeViewController;
			
			if (!_isTaxonomyPluginNode(node, NodeType.TERM)) return;

      ConnectionController.mainConnection.call(
        'graphmindTaxonomyManager.deleteTerm',
        onSuccess_TermDeleted,
        transactionError,
        node.nodeData.drupalData.tid || 0
      );
		}
		
		
		/**
		 * Callback for delete node service call.
		 */
		private static function onSuccess_TermDeleted(event:Object):void {
			// Term is deleted with all subterms
			OSD.show('Term is removed.');
		}
		
		
		/**
		 * De-pluginize a subtree.
		 */
		private static function _removePluginInfoFromNode(node:NodeViewController):void {
			node.nodeData.drupalData.plugin = undefined;
			node.nodeData.type = NodeType.NORMAL;
			node.setColor(NodeType.getNodeTypeColor(NodeType.NORMAL));
			node.view.refreshGraphics();
			
			for each (var child:NodeViewController in node.getChildNodeAll()) {
				_removePluginInfoFromNode(child);
			}
		}
		
		
		/**
		 * Implementation of hook_node_created().
		 * 
		 * @param Object data
		 */
		public static function onNodeDidAddedToParent(event:EventCenterEvent):void {
			var node:NodeViewController = event.data as NodeViewController;
			if (_isTaxonomyPluginNode(node)) {
				// Recolor taxonomy
				if (_isTaxonomyPluginNode(node, TAXONOMY_MANAGER_NODE_VOCABULARY_TYPE)) {
					node.setColor(TAXONOMY_MANAGER_NODE_VOCABULARY_COLOR);
				} else {
					node.setColor(TAXONOMY_MANAGER_NODE_TERM_COLOR);
				}
				return;
			}
			
			var parent:NodeViewController = node.getParentNode() as NodeViewController;
			if (!_isTaxonomyPluginNode(parent)) return;
			
			var subtree_node_reference:Array = new Array();
			var subtree:Object = _getSubtreeInfo(node, subtree_node_reference);
			Log.debug('Node reference: ' + subtree_node_reference);
			
			ConnectionController.mainConnection.call(
			  'graphmindTaxonomyManager.addSubtree',
        function (_event:Object):void {
          onSuccess_SubtreeAdded(_event, subtree_node_reference, node);
        },
        transactionError,
			  parent.nodeData.drupalData.tid || 0, 
			  parent.nodeData.drupalData.vid || 0, 
			  subtree
			);
		}
		
		
		/**
		 * Success event when a subtree is added.
		 */
		private static function onSuccess_SubtreeAdded(event:Object, nodeReference:Array, baseNode:NodeViewController):void {
			_convertSubtreeToTaxonomy(event, nodeReference);
			onNodeDidMoved(new EventCenterEvent(EventCenterEvent.NODE_DID_MOVED, baseNode));
			OSD.show('Subtree is added.');
		}
		
		
		/**
		 * Gather info about a subtree.
		 */
		private static function _getSubtreeInfo(node:NodeViewController, node_reference:Array):Object {
			var info:Object = new Object();
			info.name  = node.nodeData.title;
			info.terms = new Array();
			info.nrid  = node_reference.length;
			node_reference.push(node);
			
			for each (var child:NodeViewController in node.getChildNodeAll()) {
				(info.terms as Array).push(_getSubtreeInfo(child, node_reference));
			}
			
			return info;
		}
		
		
		/**
		 * Change a subtree to term tree. (Colors, types.)
		 */
		private static function _convertSubtreeToTaxonomy(subtreeInfo:Object, nodeReference:Array):void {
			if (subtreeInfo.hasOwnProperty('nrid')) {
				var node:NodeViewController = nodeReference[subtreeInfo['nrid']] as NodeViewController; 
				node.addData('tid', subtreeInfo.tid);
				node.addData('vid', subtreeInfo.vid);
				node.addData('plugin', 'TaxonomyManager');
				node.nodeData.type = NodeType.TERM;
				node.setColor(TAXONOMY_MANAGER_NODE_TERM_COLOR);
				node.refreshWithNewData();
				
				if (subtreeInfo.hasOwnProperty('terms')) {
					for each (var child:Object in subtreeInfo.terms) {
						_convertSubtreeToTaxonomy(child, nodeReference);
					}
				}
			}
		}
		
		
		/**
		 * Event callback when a node's title is changed.
		 */
		public static function onNodeTitleChanged(event:EventCenterEvent):void {
		  if (lockUpdateFlag) return;
		  
			var node:NodeViewController = event.data as NodeViewController;
			
			// Only for terms.
			if (!_isTaxonomyPluginNode(node, NodeType.TERM)) return;
			
			ConnectionController.mainConnection.call(
				'graphmindTaxonomyManager.renameTerm',
				onSuccess_TermRenamed,
				transactionError,
			  node.nodeData.drupalData.tid,
			  node.nodeData.title
			);
		}
		
		
		/**
		 * Success event when a term is renamed.
		 */
		private static function onSuccess_TermRenamed(event:Object):void {
			// Term is renamed.
			OSD.show('Term name is set.');
		}
		
		
		/**
		 * Error handler for network or request problems.
		 */
		private static function transactionError(event:Object):void {
			OSD.show(
				"Error occured during the transaction.\n" + 
				"It's very suggested to reload the whole taxonomy tree structure.",
				OSD.ERROR
			);
		}
	}
	
}
