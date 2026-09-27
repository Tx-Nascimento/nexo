import PainelOperacional from '../components/PainelOperacional'
import type { DadosUsuario } from '../types'
export default function PessoasGeralPage({ usuario }: { usuario: DadosUsuario }) { return <PainelOperacional usuario={usuario} foco="equipe" /> }
