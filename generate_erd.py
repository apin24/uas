"""Generate an ERD diagram PNG for waveneap_db MySQL schema."""
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib.lines import Line2D
import matplotlib.patheffects as path_effects

# Dark theme colors
BG_COLOR = '#1a1b26'
TABLE_BG = '#24283b'
TABLE_HEADER = '#414868'
TABLE_HEADER_TEXT = '#7aa2f7'
TEXT_COLOR = '#c0caf5'
PK_COLOR = '#e0af68'
FK_COLOR = '#bb9af7'
BORDER_COLOR = '#565f89'
LINE_COLOR = '#7aa2f7'
RELATION_COLOR = '#9ece6a'

# Schema definition: (table_name, [(col_name, col_type, is_pk, is_fk), ...], (x, y, width, height))
tables = {
    'users': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('name', 'VARCHAR', False, False),
            ('username', 'VARCHAR', False, False),
            ('email', 'VARCHAR', False, False),
            ('phone', 'VARCHAR', False, False),
            ('role', 'ENUM', False, False),
            ('password', 'VARCHAR', False, False),
            ('created_at', 'TIMESTAMP', False, False),
            ('updated_at', 'TIMESTAMP', False, False),
        ],
        'pos': (0.02, 0.55, 0.22, 0.42),
    },
    'user_profiles': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('user_id', 'BIGINT', False, True),
            ('address_street', 'VARCHAR', False, False),
            ('address_city', 'VARCHAR', False, False),
            ('address_province', 'VARCHAR', False, False),
            ('address_postal_code', 'VARCHAR', False, False),
            ('bio', 'TEXT', False, False),
            ('avatar_url', 'VARCHAR', False, False),
        ],
        'pos': (0.28, 0.55, 0.22, 0.40),
    },
    'categories': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('name', 'VARCHAR', False, False),
            ('description', 'TEXT', False, False),
            ('created_at', 'TIMESTAMP', False, False),
        ],
        'pos': (0.54, 0.62, 0.20, 0.26),
    },
    'products': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('category_id', 'BIGINT', False, True),
            ('title', 'VARCHAR', False, False),
            ('price', 'DECIMAL', False, False),
            ('description', 'TEXT', False, False),
            ('image', 'VARCHAR', False, False),
            ('created_at', 'TIMESTAMP', False, False),
            ('updated_at', 'TIMESTAMP', False, False),
        ],
        'pos': (0.78, 0.55, 0.20, 0.40),
    },
    'product_variants': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('product_id', 'BIGINT', False, True),
            ('size', 'VARCHAR', False, False),
            ('stock', 'INT', False, False),
        ],
        'pos': (0.78, 0.18, 0.20, 0.24),
    },
    'transactions': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('user_id', 'BIGINT', False, True),
            ('product_id', 'BIGINT', False, True),
            ('name', 'VARCHAR', False, False),
            ('category', 'VARCHAR', False, False),
            ('amount', 'DECIMAL', False, False),
            ('is_income', 'BOOLEAN', False, False),
            ('status', 'ENUM', False, False),
            ('transaction_date', 'DATE', False, False),
            ('platform', 'VARCHAR', False, False),
            ('variant_size', 'VARCHAR', False, False),
            ('notes', 'TEXT', False, False),
            ('created_at', 'TIMESTAMP', False, False),
            ('updated_at', 'TIMESTAMP', False, False),
        ],
        'pos': (0.30, 0.08, 0.26, 0.40),
    },
    'user_transactions': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('user_id', 'BIGINT', False, True),
            ('transaction_id', 'BIGINT', False, True),
            ('role_in_transaction', 'VARCHAR', False, False),
            ('assigned_at', 'TIMESTAMP', False, False),
        ],
        'pos': (0.04, 0.08, 0.22, 0.30),
    },
    'activity_logs': {
        'columns': [
            ('id', 'BIGINT', True, False),
            ('table_name', 'VARCHAR', False, False),
            ('record_id', 'BIGINT', False, False),
            ('action', 'ENUM', False, False),
            ('old_values', 'JSON', False, False),
            ('new_values', 'JSON', False, False),
            ('changed_by', 'BIGINT', False, False),
            ('changed_at', 'TIMESTAMP', False, False),
        ],
        'pos': (0.60, 0.18, 0.22, 0.30),
    },
}

# Relationships: (from_table, to_table, from_col, to_col, cardinality, label_side)
# cardinality: '1:1', '1:N', 'M:N'
relationships = [
    ('users', 'user_profiles', 'id', 'user_id', '1:1'),
    ('categories', 'products', 'id', 'category_id', '1:N'),
    ('products', 'product_variants', 'id', 'product_id', '1:N'),
    ('products', 'transactions', 'id', 'product_id', '1:N'),
    ('users', 'transactions', 'id', 'user_id', '1:N'),
    ('users', 'user_transactions', 'id', 'user_id', '1:N'),
    ('transactions', 'user_transactions', 'id', 'transaction_id', '1:N'),
]


def get_column_y(table_info, col_name, row_height=0.022, header_height=0.045):
    """Get the y-position (center) of a specific column in a table."""
    cols = table_info['columns']
    x, y, w, h = table_info['pos']
    # Find column index
    idx = None
    for i, c in enumerate(cols):
        if c[0] == col_name:
            idx = i
            break
    if idx is None:
        return y + h - header_height  # default to header
    # Header is at top, columns below
    col_y = y + h - header_height - (idx + 0.5) * row_height
    return col_y


def get_table_anchor(table_info, col_name, side='left'):
    """Get the (x, y) anchor point for a column on left or right side of table."""
    x, y, w, h = table_info['pos']
    col_y = get_column_y(table_info, col_name)
    if side == 'left':
        return (x, col_y)
    else:
        return (x + w, col_y)


def draw_table(ax, name, info):
    x, y, w, h = info['pos']
    columns = info['columns']
    
    # Table body
    box = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.003,rounding_size=0.012",
        linewidth=1.2,
        edgecolor=BORDER_COLOR,
        facecolor=TABLE_BG,
        zorder=2,
    )
    ax.add_patch(box)
    
    # Header bar
    header_h = 0.045
    header_box = FancyBboxPatch(
        (x, y + h - header_h), w, header_h,
        boxstyle="round,pad=0.003,rounding_size=0.012",
        linewidth=0,
        facecolor=TABLE_HEADER,
        zorder=3,
    )
    ax.add_patch(header_box)
    
    # Header text
    ax.text(
        x + w / 2, y + h - header_h / 2,
        name,
        ha='center', va='center',
        fontsize=9, fontweight='bold',
        color=TABLE_HEADER_TEXT,
        fontfamily='monospace',
        zorder=4,
    )
    
    # Columns
    row_h = 0.022
    for i, (col_name, col_type, is_pk, is_fk) in enumerate(columns):
        cy = y + h - header_h - (i + 0.5) * row_h
        # Alternate row backgrounds
        if i % 2 == 0:
            row_bg = mpatches.Rectangle(
                (x + 0.003, cy - row_h / 2), w - 0.006, row_h,
                facecolor='#2b3146', edgecolor='none', zorder=2.5,
            )
            ax.add_patch(row_bg)
        
        # Column name with key indicators
        prefix = ''
        color = TEXT_COLOR
        if is_pk:
            prefix = 'PK '
            color = PK_COLOR
        elif is_fk:
            prefix = 'FK '
            color = FK_COLOR
        
        # Key marker dot
        if is_pk:
            ax.plot(x + 0.01, cy, 'o', markersize=4, color=PK_COLOR, zorder=5)
        elif is_fk:
            ax.plot(x + 0.01, cy, 'o', markersize=4, color=FK_COLOR, zorder=5)
        
        ax.text(
            x + 0.02, cy,
            f"{prefix}{col_name}",
            ha='left', va='center',
            fontsize=6.5, fontweight='bold' if is_pk else 'normal',
            color=color,
            fontfamily='monospace',
            zorder=5,
        )
        
        # Type on right
        ax.text(
            x + w - 0.01, cy,
            col_type,
            ha='right', va='center',
            fontsize=5.5,
            color='#565f89',
            fontfamily='monospace',
            zorder=5,
        )


def draw_crowfoot(ax, x, y, direction, cardinality):
    """Draw crow's foot notation at a point.
    direction: 'right' (pointing right), 'left' (pointing left)
    cardinality: 'one' or 'many'
    """
    size = 0.012
    
    if cardinality == 'one':
        # Single bar
        if direction == 'right':
            ax.plot([x - size, x - size], [y - size, y + size], '-', color=LINE_COLOR, linewidth=1.8, zorder=6)
        else:
            ax.plot([x + size, x + size], [y - size, y + size], '-', color=LINE_COLOR, linewidth=1.8, zorder=6)
    elif cardinality == 'many':
        # Crow's foot (three lines fanning out)
        if direction == 'right':
            # base is to the left, foot opens to the right
            ax.plot([x - size, x + size], [y, y + size], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
            ax.plot([x - size, x + size], [y, y], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
            ax.plot([x - size, x + size], [y, y - size], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
            # bar
            ax.plot([x - size*1.8, x - size*1.8], [y - size*0.7, y + size*0.7], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
        else:
            ax.plot([x + size, x - size], [y, y + size], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
            ax.plot([x + size, x - size], [y, y], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
            ax.plot([x + size, x - size], [y, y - size], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)
            ax.plot([x + size*1.8, x + size*1.8], [y - size*0.7, y + size*0.7], '-', color=LINE_COLOR, linewidth=1.5, zorder=6)


def draw_relationship(ax, from_table, to_table, from_col, to_col, cardinality):
    """Draw a relationship line with crow's foot notation."""
    from_info = tables[from_table]
    to_info = tables[to_table]
    
    fx, fy, fw, fh = from_info['pos']
    tx, ty, tw, th = to_info['pos']
    
    # Determine connection sides
    from_col_y = get_column_y(from_info, from_col)
    to_col_y = get_column_y(to_info, to_col)
    
    # Decide which sides to connect (left or right of each table)
    from_center_x = fx + fw / 2
    to_center_x = tx + tw / 2
    
    if to_center_x > from_center_x:
        # Connect right of from -> left of to
        from_x = fx + fw
        to_x = tx
        from_dir = 'right'
        to_dir = 'left'
    else:
        # Connect left of from -> right of to
        from_x = fx
        to_x = tx + tw
        from_dir = 'left'
        to_dir = 'right'
    
    from_y = from_col_y
    to_y = to_col_y
    
    # Draw the connection line with an orthogonal/curved path
    mid_x = (from_x + to_x) / 2
    
    # Use a smooth curved line
    verts_x = [from_x, from_x + (to_x - from_x) * 0.3, to_x - (to_x - from_x) * 0.3, to_x]
    verts_y = [from_y, from_y, to_y, to_y]
    
    # Draw as smooth curve
    from scipy.interpolate import make_interp_spline
    import numpy as np
    
    t = np.linspace(0, 1, 50)
    spl = make_interp_spline([0, 0.33, 0.66, 1], [from_y, from_y, to_y, to_y], k=2)
    y_curve = spl(t)
    spl_x = make_interp_spline([0, 0.33, 0.66, 1], [from_x, from_x + (to_x - from_x) * 0.3, to_x - (to_x - from_x) * 0.3, to_x], k=2)
    x_curve = spl_x(t)
    
    ax.plot(x_curve, y_curve, '-', color=LINE_COLOR, linewidth=1.3, alpha=0.85, zorder=1)
    
    # Draw crow's foot notation
    if cardinality == '1:1':
        draw_crowfoot(ax, from_x, from_y, from_dir, 'one')
        draw_crowfoot(ax, to_x, to_y, to_dir, 'one')
    elif cardinality == '1:N':
        # from is the "one" side, to is the "many" side
        draw_crowfoot(ax, from_x, from_y, from_dir, 'one')
        draw_crowfoot(ax, to_x, to_y, to_dir, 'many')
    elif cardinality == 'M:N':
        draw_crowfoot(ax, from_x, from_y, from_dir, 'many')
        draw_crowfoot(ax, to_x, to_y, to_dir, 'many')
    
    # Label in the middle
    mid_x_label = (from_x + to_x) / 2
    mid_y_label = (from_y + to_y) / 2
    ax.text(
        mid_x_label, mid_y_label + 0.015,
        cardinality,
        ha='center', va='center',
        fontsize=5.5,
        color=RELATION_COLOR,
        fontfamily='monospace',
        fontweight='bold',
        zorder=7,
        bbox=dict(boxstyle='round,pad=0.15', facecolor=BG_COLOR, edgecolor=RELATION_COLOR, linewidth=0.5, alpha=0.9),
    )


def main():
    fig, ax = plt.subplots(1, 1, figsize=(20, 14), dpi=150)
    fig.patch.set_facecolor(BG_COLOR)
    ax.set_facecolor(BG_COLOR)
    ax.set_xlim(0, 1.02)
    ax.set_ylim(0, 1.02)
    ax.set_aspect('auto')
    ax.axis('off')
    
    # Title
    ax.text(
        0.51, 0.995,
        'waveneap_db — Entity Relationship Diagram',
        ha='center', va='top',
        fontsize=15, fontweight='bold',
        color='#7aa2f7',
        fontfamily='monospace',
    )
    
    # Draw all tables
    for name, info in tables.items():
        draw_table(ax, name, info)
    
    # Draw all relationships
    for rel in relationships:
        draw_relationship(ax, *rel)
    
    # Legend
    legend_x = 0.02
    legend_y = 0.01
    ax.text(legend_x, legend_y + 0.025, 'Legend:', fontsize=7, color=TEXT_COLOR, fontfamily='monospace', fontweight='bold')
    ax.plot(legend_x + 0.03, legend_y + 0.025, 'o', markersize=5, color=PK_COLOR)
    ax.text(legend_x + 0.04, legend_y + 0.025, 'PK = Primary Key', fontsize=6, color=PK_COLOR, fontfamily='monospace', va='center')
    ax.plot(legend_x + 0.16, legend_y + 0.025, 'o', markersize=5, color=FK_COLOR)
    ax.text(legend_x + 0.17, legend_y + 0.025, 'FK = Foreign Key', fontsize=6, color=FK_COLOR, fontfamily='monospace', va='center')
    
    # Cardinality legend
    ax.text(legend_x + 0.30, legend_y + 0.025, '1:1 = One-to-One', fontsize=6, color=RELATION_COLOR, fontfamily='monospace', va='center')
    ax.text(legend_x + 0.42, legend_y + 0.025, '1:N = One-to-Many', fontsize=6, color=RELATION_COLOR, fontfamily='monospace', va='center')
    ax.text(legend_x + 0.54, legend_y + 0.025, 'M:N = Many-to-Many (via join table)', fontsize=6, color=RELATION_COLOR, fontfamily='monospace', va='center')
    
    plt.tight_layout(pad=0.5)
    output_path = r'C:\Users\User\Downloads\uas-pbd-ilham\erd.png'
    plt.savefig(output_path, dpi=150, facecolor=BG_COLOR, bbox_inches='tight', pad_inches=0.2)
    plt.close()
    print(f"ERD saved to: {output_path}")


if __name__ == '__main__':
    main()
