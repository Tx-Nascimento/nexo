import type { ReactNode } from 'react'
import type { DadosUsuario, Pagina } from '../types'

type Props = {
  usuario: DadosUsuario
  pagina: Pagina
  navegar: (pagina: Pagina) => void
  sair: () => void
  children: ReactNode
}

export default function Layout({
  usuario,
  pagina,
  navegar,
  sair,
  children,
}: Props) {
  function ativo(...paginas: Pagina[]) {
    return paginas.includes(pagina) ? 'active' : ''
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-title">NEXO</div>
          <div className="brand-subtitle">
            Sistema Operacional da Administração
          </div>
        </div>

        <nav className="menu">
          <button
            className={`menu-item ${ativo('central')}`}
            onClick={() => navegar('central')}
          >
            Minha Central
          </button>

          <button
            className={`menu-item ${ativo('operacoes')}`}
            onClick={() => navegar('operacoes')}
          >
            Operações
          </button>

          <button
            className={`menu-item ${ativo('demandas')}`}
            onClick={() => navegar('demandas')}
          >
            Demandas
          </button>

          <button
            className={`menu-item ${ativo('processos-geral')}`}
            onClick={() => navegar('processos-geral')}
          >
            Processos
          </button>

          <button
            className={`menu-item ${ativo('pessoas-geral')}`}
            onClick={() => navegar('pessoas-geral')}
          >
            Pessoas
          </button>

          <button
            className={`menu-item ${ativo('documentos')}`}
            onClick={() => navegar('documentos')}
          >
            Documentos
          </button>

          <button
            className={`menu-item ${ativo('indicadores')}`}
            onClick={() => navegar('indicadores')}
          >
            Indicadores
          </button>

          {usuario.perfil === 'ADMIN' && (
            <button
              className={`menu-item ${ativo(
                'administracao',
                'empresas',
                'setores',
                'cargos',
                'pessoas',
                'perfis',
                'processos',
                'cadastro-operacoes',
                'responsabilidades',
                'recorrencias'
              )}`}
              onClick={() => navegar('administracao')}
            >
              Administração
            </button>
          )}
        </nav>

        <div className="sidebar-user">
          <div className="user-name">{usuario.nome}</div>
          <div className="user-role">{usuario.perfil}</div>

          <button className="logout-button" onClick={sair}>
            Sair
          </button>
        </div>
      </aside>

      <main className="main-content">{children}</main>
    </div>
  )
}