// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/intermediate/IntermediateProcessorStrategy.java

import Foundation

package enum IntermediateProcessorStrategy: CaseIterable, EnumOrdinal, ILayoutProcessorFactory {
    package var ordinal: Int {
        Self.allCases.firstIndex(of: self)!
    }

    package typealias G = LGraph

    case DIRECTION_PREPROCESSOR
    case COMMENT_PREPROCESSOR
    case EDGE_AND_LAYER_CONSTRAINT_EDGE_REVERSER
    case INTERACTIVE_EXTERNAL_PORT_POSITIONER
    case PARTITION_PREPROCESSOR
    case LABEL_DUMMY_INSERTER
    case SELF_LOOP_PREPROCESSOR
    case LAYER_CONSTRAINT_PREPROCESSOR
    case PARTITION_MIDPROCESSOR
    case HIGH_DEGREE_NODE_LAYER_PROCESSOR
    case NODE_PROMOTION
    case LAYER_CONSTRAINT_POSTPROCESSOR
    case PARTITION_POSTPROCESSOR
    case HIERARCHICAL_PORT_CONSTRAINT_PROCESSOR
    case SEMI_INTERACTIVE_CROSSMIN_PROCESSOR
    case BREAKING_POINT_INSERTER
    case LONG_EDGE_SPLITTER
    case PORT_SIDE_PROCESSOR
    case INVERTED_PORT_PROCESSOR
    case PORT_LIST_SORTER
    case SORT_BY_INPUT_ORDER_OF_MODEL
    case NORTH_SOUTH_PORT_PREPROCESSOR
    case BREAKING_POINT_PROCESSOR
    case ONE_SIDED_GREEDY_SWITCH
    case TWO_SIDED_GREEDY_SWITCH
    case SELF_LOOP_PORT_RESTORER
    case ALTERNATING_LAYER_UNZIPPER
    case SINGLE_EDGE_GRAPH_WRAPPER
    case IN_LAYER_CONSTRAINT_PROCESSOR
    case END_NODE_PORT_LABEL_MANAGEMENT_PROCESSOR
    case LABEL_AND_NODE_SIZE_PROCESSOR
    case INNERMOST_NODE_MARGIN_CALCULATOR
    case SELF_LOOP_ROUTER
    case COMMENT_NODE_MARGIN_CALCULATOR
    case END_LABEL_PREPROCESSOR
    case LABEL_DUMMY_SWITCHER
    case CENTER_LABEL_MANAGEMENT_PROCESSOR
    case LABEL_SIDE_SELECTOR
    case HYPEREDGE_DUMMY_MERGER
    case HIERARCHICAL_PORT_DUMMY_SIZE_PROCESSOR
    case LAYER_SIZE_AND_GRAPH_HEIGHT_CALCULATOR
    case HIERARCHICAL_PORT_POSITION_PROCESSOR
    case CONSTRAINTS_POSTPROCESSOR
    case COMMENT_POSTPROCESSOR
    case HYPERNODE_PROCESSOR
    case HIERARCHICAL_PORT_ORTHOGONAL_EDGE_ROUTER
    case LONG_EDGE_JOINER
    case SELF_LOOP_POSTPROCESSOR
    case BREAKING_POINT_REMOVER
    case NORTH_SOUTH_PORT_POSTPROCESSOR
    case HORIZONTAL_COMPACTOR
    case LABEL_DUMMY_REMOVER
    case FINAL_SPLINE_BENDPOINTS_CALCULATOR
    case END_LABEL_SORTER
    case REVERSED_EDGE_RESTORER
    case END_LABEL_POSTPROCESSOR
    case HIERARCHICAL_NODE_RESIZER
    case DIRECTION_POSTPROCESSOR

    package func create() -> any ILayoutProcessor {
        switch self {
        case .BREAKING_POINT_INSERTER:
            return BreakingPointInserter()
        case .BREAKING_POINT_PROCESSOR:
            return BreakingPointProcessor()
        case .BREAKING_POINT_REMOVER:
            return BreakingPointRemover()
        case .CENTER_LABEL_MANAGEMENT_PROCESSOR:
            return LabelManagementProcessor(true)
        case .COMMENT_NODE_MARGIN_CALCULATOR:
            return CommentNodeMarginCalculator()
        case .COMMENT_POSTPROCESSOR:
            return CommentPostprocessor()
        case .COMMENT_PREPROCESSOR:
            return CommentPreprocessor()
        case .CONSTRAINTS_POSTPROCESSOR:
            return ConstraintsPostprocessor()
        case .DIRECTION_POSTPROCESSOR:
            return GraphTransformer(.TO_INTERNAL_LTR)
        case .DIRECTION_PREPROCESSOR:
            return GraphTransformer(.TO_INPUT_DIRECTION)
        case .EDGE_AND_LAYER_CONSTRAINT_EDGE_REVERSER:
            return EdgeAndLayerConstraintEdgeReverser()
        case .END_LABEL_POSTPROCESSOR:
            return EndLabelPostprocessor()
        case .END_LABEL_PREPROCESSOR:
            return EndLabelPreprocessor()
        case .END_NODE_PORT_LABEL_MANAGEMENT_PROCESSOR:
            return LabelManagementProcessor(false)
        case .FINAL_SPLINE_BENDPOINTS_CALCULATOR:
            assertionFailure("Spline routing is not supported")
            return _NoOpProcessor()
        case .HIERARCHICAL_NODE_RESIZER:
            return HierarchicalNodeResizingProcessor()
        case .HIERARCHICAL_PORT_CONSTRAINT_PROCESSOR:
            return HierarchicalPortConstraintProcessor()
        case .HIERARCHICAL_PORT_DUMMY_SIZE_PROCESSOR:
            return HierarchicalPortDummySizeProcessor()
        case .HIERARCHICAL_PORT_ORTHOGONAL_EDGE_ROUTER:
            return HierarchicalPortOrthogonalEdgeRouter()
        case .HIERARCHICAL_PORT_POSITION_PROCESSOR:
            return HierarchicalPortPositionProcessor()
        case .HIGH_DEGREE_NODE_LAYER_PROCESSOR:
            return HighDegreeNodeLayeringProcessor()
        case .HORIZONTAL_COMPACTOR:
            return HorizontalGraphCompactor()
        case .HYPEREDGE_DUMMY_MERGER:
            return HyperedgeDummyMerger()
        case .HYPERNODE_PROCESSOR:
            return HypernodesProcessor()
        case .IN_LAYER_CONSTRAINT_PROCESSOR:
            return InLayerConstraintProcessor()
        case .INNERMOST_NODE_MARGIN_CALCULATOR:
            return InnermostNodeMarginCalculator()
        case .INTERACTIVE_EXTERNAL_PORT_POSITIONER:
            return InteractiveExternalPortPositioner()
        case .INVERTED_PORT_PROCESSOR:
            return InvertedPortProcessor()
        case .LABEL_AND_NODE_SIZE_PROCESSOR:
            return LabelAndNodeSizeProcessor()
        case .LABEL_DUMMY_INSERTER:
            return LabelDummyInserter()
        case .LABEL_DUMMY_REMOVER:
            return LabelDummyRemover()
        case .LABEL_DUMMY_SWITCHER:
            return LabelDummySwitcher()
        case .LABEL_SIDE_SELECTOR:
            return LabelSideSelector()
        case .END_LABEL_SORTER:
            return EndLabelSorter()
        case .LAYER_CONSTRAINT_POSTPROCESSOR:
            return LayerConstraintPostprocessor()
        case .LAYER_CONSTRAINT_PREPROCESSOR:
            return LayerConstraintPreprocessor()
        case .LAYER_SIZE_AND_GRAPH_HEIGHT_CALCULATOR:
            return LayerSizeAndGraphHeightCalculator()
        case .LONG_EDGE_JOINER:
            return LongEdgeJoiner()
        case .LONG_EDGE_SPLITTER:
            return LongEdgeSplitter()
        case .NODE_PROMOTION:
            return NodePromotion()
        case .NORTH_SOUTH_PORT_POSTPROCESSOR:
            return NorthSouthPortPostprocessor()
        case .NORTH_SOUTH_PORT_PREPROCESSOR:
            return NorthSouthPortPreprocessor()
        case .ONE_SIDED_GREEDY_SWITCH:
            return LayerSweepCrossingMinimizer(.ONE_SIDED_GREEDY_SWITCH)
        case .PARTITION_MIDPROCESSOR:
            return PartitionMidprocessor()
        case .PARTITION_POSTPROCESSOR:
            return PartitionPostprocessor()
        case .PARTITION_PREPROCESSOR:
            return PartitionPreprocessor()
        case .PORT_LIST_SORTER:
            return PortListSorter()
        case .PORT_SIDE_PROCESSOR:
            return PortSideProcessor()
        case .REVERSED_EDGE_RESTORER:
            return ReversedEdgeRestorer()
        case .SELF_LOOP_PREPROCESSOR:
            return SelfLoopPreProcessor()
        case .SELF_LOOP_PORT_RESTORER:
            return SelfLoopPortRestorer()
        case .ALTERNATING_LAYER_UNZIPPER:
            return AlternatingLayerUnzipper()
        case .SELF_LOOP_POSTPROCESSOR:
            return SelfLoopPostProcessor()
        case .SELF_LOOP_ROUTER:
            return SelfLoopRouter()
        case .SEMI_INTERACTIVE_CROSSMIN_PROCESSOR:
            return SemiInteractiveCrossMinProcessor()
        case .SINGLE_EDGE_GRAPH_WRAPPER:
            return SingleEdgeGraphWrapper()
        case .SORT_BY_INPUT_ORDER_OF_MODEL:
            return SortByInputModelProcessor()
        case .TWO_SIDED_GREEDY_SWITCH:
            return LayerSweepCrossingMinimizer(.TWO_SIDED_GREEDY_SWITCH)
        }
    }
}

private struct _NoOpProcessor: ILayoutProcessor {
    typealias G = LGraph
    func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}

// Stub types: need typealias G and process method for ILayoutProcessor conformance
extension BreakingPointInserter: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension BreakingPointProcessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension BreakingPointRemover: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension LabelManagementProcessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
// Classes that already declare : ILayoutProcessor and have process method - no redundant conformance needed
// CommentNodeMarginCalculator, CommentPostprocessor, CommentPreprocessor, ConstraintsPostprocessor
// EdgeAndLayerConstraintEdgeReverser, EndLabelPostprocessor, EndLabelSorter, DummySelfLoopProcessor

extension GraphTransformer: ILayoutProcessor {
    package typealias G = LGraph
}
// EndLabelPreprocessor has process method but doesn't declare : ILayoutProcessor
extension EndLabelPreprocessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {
        process(graph, monitor: progressMonitor)
    }
}
extension HierarchicalNodeResizingProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension HierarchicalPortConstraintProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension HierarchicalPortDummySizeProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension HierarchicalPortOrthogonalEdgeRouter: ILayoutProcessor {
    package typealias G = LGraph
}
extension HierarchicalPortPositionProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension HighDegreeNodeLayeringProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension HorizontalGraphCompactor: ILayoutProcessor {
    package typealias G = LGraph
}
extension HyperedgeDummyMerger: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension HypernodesProcessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension InLayerConstraintProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension InnermostNodeMarginCalculator: ILayoutProcessor {
    package typealias G = LGraph
}
extension InteractiveExternalPortPositioner: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension InvertedPortProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension LabelAndNodeSizeProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension LabelDummyInserter: ILayoutProcessor {
    package typealias G = LGraph
}
extension LabelDummyRemover: ILayoutProcessor {
    package typealias G = LGraph
}
extension LabelDummySwitcher: ILayoutProcessor {
    package typealias G = LGraph
}
extension LabelSideSelector: ILayoutProcessor {
    package typealias G = LGraph
}
extension LayerConstraintPostprocessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension LayerConstraintPreprocessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension LayerSizeAndGraphHeightCalculator: ILayoutProcessor {
    package typealias G = LGraph
}
extension LongEdgeJoiner: ILayoutProcessor {
    package typealias G = LGraph
}
extension LongEdgeSplitter: ILayoutProcessor {
    package typealias G = LGraph
}
extension NodePromotion: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension NorthSouthPortPostprocessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension NorthSouthPortPreprocessor: ILayoutProcessor {
    package typealias G = LGraph
}
// LayerSweepCrossingMinimizer already conforms to ILayoutProcessor via ILayoutPhase in CrossingMinimizationStrategy
extension PartitionMidprocessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension PartitionPostprocessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension PartitionPreprocessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension PortListSorter: ILayoutProcessor {
    package typealias G = LGraph
}
extension PortSideProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
extension ReversedEdgeRestorer: ILayoutProcessor {
    package typealias G = LGraph
}
// SelfLoopPreProcessor declares its own ILayoutProcessor conformance
// SelfLoopPortRestorer declares its own ILayoutProcessor conformance
extension AlternatingLayerUnzipper: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
// SelfLoopPostProcessor declares its own ILayoutProcessor conformance
// SelfLoopRouter declares its own ILayoutProcessor conformance
extension SemiInteractiveCrossMinProcessor: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension SingleEdgeGraphWrapper: ILayoutProcessor {
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
}
extension SortByInputModelProcessor: ILayoutProcessor {
    package typealias G = LGraph
}
