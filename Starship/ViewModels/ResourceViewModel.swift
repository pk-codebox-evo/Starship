//
//  ResourceViewModel.swift
//  Starship
//
//  Created by Kyle Fuller on 01/07/2015.
//  Copyright (c) 2015 Kyle Fuller. All rights reserved.
//

import Foundation
import Representor
import Hyperdrive


enum ResourceViewModelResult {
  case Success(ResourceViewModel)
  case Refresh
  case Failure(NSError)
}

class ResourceViewModel {
  // MARK: RepresentorViewModel

  let hyperdrive:Hyperdrive
  private(set) var representor:Representor<HTTPTransition>

  init(hyperdrive:Hyperdrive, representor:Representor<HTTPTransition>) {
    self.hyperdrive = hyperdrive
    self.representor = representor
  }

  var canReload:Bool {
    return self.representor.transitions["self"] != nil
  }

  func reload(completion:((RepresentorResult) -> ())) {
    if let uri = self.representor.transitions["self"] {
      hyperdrive.request(uri) { result in
        switch result {
        case .Success(let representor):
          self.representor = representor
        case .Failure:
          break
        }

        completion(result)
      }
    }
  }

  // MARK: Private

  private var attributes:[(key:String, value:AnyObject)] {
    return representor.attributes.map { (key, value) in
      return (key: key, value: value)
    }
  }

  private var embeddedResources:[(relation:String, representor:Representor<HTTPTransition>)] {
    return representor.representors.reduce([]) { (accumulator, resources) in
      let name = resources.0

      return accumulator + resources.1.map { representor in
        return (relation: name, representor: representor)
      }
    }
  }

  private var transitions:[(relation:String, transition:HTTPTransition)] {
    return representor.transitions
      .filter { (relation, transition) in relation != "self" }
      .map { (relation, transition) in (relation: relation, transition: transition) }
  }

  // MARK: Other

  var title:String? {
    return titlify(representor)
  }

  private func titlify(representor:Representor<HTTPTransition>) -> String? {
    for key in ["title", "name", "question", "choice"] {
      if let value = representor.attributes[key] as? String {
        return value
      }
    }

    return nil
  }

  // MARK: Attributes

  var numberOfAttributes:Int {
    return representor.attributes.count
  }

  func titleForAttribute(index:Int) -> String {
    return attributes[index].key
  }

  func valueForAttribute(index:Int) -> String {
    return "\(attributes[index].value)"
  }

  // MARK: Embedded Resources

  var numberOfEmbeddedResources:Int {
    return embeddedResources.count
  }

  func titleForEmbeddedResource(index:Int) -> String? {
    return titlify(embeddedResources[index].representor)
  }

  func relationForEmbeddedResource(index:Int) -> String {
    return embeddedResources[index].relation
  }

  func viewModelForEmbeddedResource(index:Int) -> ResourceViewModel {
    let representor = embeddedResources[index].representor
    return ResourceViewModel(hyperdrive: hyperdrive, representor: representor)
  }

  // MARK: Transitions

  var numberOfTransitions:Int {
    return transitions.count
  }

  func titleForTransition(index:Int) -> String {
    return transitions[index].relation
  }

  func viewModelForTransition(index:Int) -> TransitionViewModel? {
    let transition = transitions[index].transition

    if (transition.parameters.count + transition.attributes.count) > 0 {
      return TransitionViewModel(hyperdrive: hyperdrive, transition: transition)
    }

    return nil
  }

  func performTransition(index:Int, completion:(ResourceViewModelResult -> ())) {
    hyperdrive.request(transitions[index].transition) { result in
      switch result {
      case .Success(let representor):
        if let oldSelf = self.representor.transitions["self"], newSelf = representor.transitions["self"] {
          if oldSelf.uri == newSelf.uri {
            self.representor = representor
            completion(.Refresh)
            return
          }
        }

        completion(.Success(ResourceViewModel(hyperdrive: self.hyperdrive, representor: representor)))
      case .Failure(let error):
        completion(.Failure(error))
      }
    }
  }
}
