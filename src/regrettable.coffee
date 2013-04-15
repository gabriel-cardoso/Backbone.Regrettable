_ = if require? then require("underscore") else window._
Backbone = if require? then require("backbone") else window.Backbone

class Action
  constructor: ->
  undo: ->
  redo: ->

class CollectionAddAction extends Action
  constructor: (@collection, @model) ->
  undo: -> @model.destroy()
  redo: -> @model = @model.clone(); @collection.add(@model)

class CollectionRemoveAction extends Action
  constructor: (@collection, @model) ->
  undo: -> @model = @model.clone(); @collection.add(@model)
  redo: -> @model.destroy()

class ModelPropertyUpdateAction extends Action
  constructor: (@model, @prop, @newVal, @oldVal ) ->
  undo: -> @model.set(@prop, @oldVal)
  redo: -> @model.set(@prop, @newVal)

class ModelUpdateAction extends Action
  constructor: (@model) ->
    @actions = []
    for attr, newVal of @model.changedAttributes()
      @actions.push(new ModelPropertyUpdateAction(@model, attr, newVal, @model.previous(attr)))

  undo: -> _.invoke @actions, 'undo'
  redo: -> _.invoke @actions, 'redo'

Backbone.Regrettable = (->

  undoStack = []
  redoStack = []
  tracking = true

  undoStack: -> undoStack
  redoStack: -> redoStack
  undo: ->
    return if undoStack.length == 0
    try
      tracking = false
      action = undoStack.pop()
      action.undo()
      redoStack.push(action)
    finally
      tracking = true
  redo: ->
    return if redoStack.length == 0
    try
      tracking = false
      action = redoStack.pop()
      action.redo()
      undoStack.push(action)
    finally
      tracking = true
  hasUndo: ->
    return undoStack.length > 0
  hasRedo: ->
    return redoStack.length > 0
  reset: ->
    undoStack = []
    redoStack = []
  bind: (o, opts = {}) ->
    ignore = opts.ignore || (-> false)
    if o instanceof Backbone.Model
      o.on "change", (model, opts) ->
        if tracking && not ignore(model, opts)
          undoStack.push(new ModelUpdateAction(model))
    else if o instanceof Backbone.Collection
      o.on "add", (prod, coll, opts) ->
        if tracking && not ignore(prod, coll, opts)
          undoStack.push(new CollectionAddAction(o, prod))
      o.on "remove", (prod, coll, opts) ->
        if tracking && not ignore(prod, coll, opts)
          undoStack.push(new CollectionRemoveAction(o, prod))
)()


if module?.exports?

  _.extend Backbone.Regrettable,
    CollectionAddAction: CollectionAddAction
    CollectionRemoveAction: CollectionRemoveAction
    ModelUpdateAction: ModelUpdateAction

  module.exports = Backbone.Regrettable




