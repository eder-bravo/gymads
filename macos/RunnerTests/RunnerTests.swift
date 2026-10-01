import Cocoa
import FlutterMacOS
import XCTest
@testable import gymads

class RunnerTests: XCTestCase {

  func testPermisoSinRespuestaTerminaEIgnoraUnaRespuestaTardia() {
    let termino = expectation(description: "respuesta tardía")
    var estados = [String]()
    let respuesta = RespuestaPermiso({ valor in
      estados.append(valor as! String)
    }, plazo: 0.01, alAgotar: { "sinDato" })

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      respuesta.enviar("permitido")
      termino.fulfill()
    }
    wait(for: [termino], timeout: 1)
    XCTAssertEqual(estados, ["sinDato"])
    XCTAssertTrue(respuesta.terminada)
  }

  func testRespuestaNormalCancelaElLimiteDeEspera() {
    let termino = expectation(description: "límite cancelado")
    var estados = [String]()
    var agotados = 0
    let respuesta = RespuestaPermiso({ valor in
      estados.append(valor as! String)
    }, plazo: 0.01, alAgotar: {
      agotados += 1
      return "sinDato"
    })
    respuesta.enviar("permitido")

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      termino.fulfill()
    }
    wait(for: [termino], timeout: 1)
    XCTAssertEqual(estados, ["permitido"])
    XCTAssertEqual(agotados, 0)
  }

}
