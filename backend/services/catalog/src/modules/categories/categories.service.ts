import { AppError, Errors, requireShopId } from '@qc/common';
import type { Db } from '../../db.js';
import { Prisma, type Category } from '../../generated/prisma/client.js';
import type { MediaResolver } from '../../upstreams.js';

type I18n = Record<string, string> | null | undefined;

export interface CategoryInput {
  name: string;
  nameI18n?: I18n;
  parentId?: string | null;
  imageMediaId?: string | null;
  sortOrder?: number;
  isActive?: boolean;
}

export interface PublicCategory {
  id: string;
  parentId: string | null;
  name: string;
  nameI18n: I18n;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
}

export const toPublicCategory = (c: Category): PublicCategory => ({
  id: c.id,
  parentId: c.parentId,
  name: c.name,
  nameI18n: (c.nameI18n as I18n) ?? null,
  imageUrl: c.imageUrl,
  sortOrder: c.sortOrder,
  isActive: c.isActive,
});

/** undefined = leave unchanged, null = clear. */
export const i18nJson = (value: I18n) =>
  value === null ? Prisma.DbNull : (value as Prisma.InputJsonValue | undefined);
const ORDER: Prisma.CategoryOrderByWithRelationInput[] = [{ sortOrder: 'asc' }, { name: 'asc' }];

export function createCategoriesService(db: Db, media: MediaResolver, now: () => Date = () => new Date()) {
  async function get(id: string): Promise<Category> {
    const category = await db.category.findFirst({ where: { id, deletedAt: null } });
    if (!category) throw Errors.notFound('CATEGORY_NOT_FOUND', 'Category not found');
    return category;
  }

  /** Categories are two levels deep: a parent must be an existing top-level category. */
  async function checkParent(parentId: string | null | undefined, selfId?: string): Promise<void> {
    if (!parentId) return;
    if (parentId === selfId) throw Errors.badRequest('CATEGORY_PARENT_INVALID', 'A category cannot be its own parent');
    const parent = await db.category.findFirst({ where: { id: parentId, deletedAt: null } });
    if (!parent) throw Errors.badRequest('CATEGORY_PARENT_INVALID', 'Parent category not found');
    if (parent.parentId) throw Errors.badRequest('CATEGORY_PARENT_INVALID', 'Sub-categories cannot have sub-categories');
    if (selfId && (await db.category.count({ where: { parentId: selfId, deletedAt: null } })) > 0) {
      throw Errors.badRequest('CATEGORY_PARENT_INVALID', 'A category with sub-categories cannot become a sub-category');
    }
  }

  async function image(mediaId: string | null | undefined) {
    if (mediaId === undefined) return {};
    if (mediaId === null) return { imageMediaId: null, imageUrl: null };
    const [found] = await media.resolve([mediaId]);
    if (!found) throw Errors.badRequest('MEDIA_NOT_FOUND', 'Image not found');
    return { imageMediaId: found.id, imageUrl: found.thumbUrl };
  }

  return {
    get,

    /** Active categories for customers. Sub-categories of hidden parents are hidden too. */
    async listPublic(): Promise<PublicCategory[]> {
      const rows = await db.category.findMany({ where: { deletedAt: null, isActive: true }, orderBy: ORDER });
      const visible = new Set(rows.map((c) => c.id));
      return rows.filter((c) => !c.parentId || visible.has(c.parentId)).map(toPublicCategory);
    },

    async listAll(): Promise<PublicCategory[]> {
      const rows = await db.category.findMany({ where: { deletedAt: null }, orderBy: ORDER });
      return rows.map(toPublicCategory);
    },

    async create(input: CategoryInput): Promise<PublicCategory> {
      await checkParent(input.parentId);
      const category = await db.category.create({
        data: {
          shopId: requireShopId(),
          name: input.name,
          nameI18n: i18nJson(input.nameI18n),
          parentId: input.parentId ?? null,
          sortOrder: input.sortOrder ?? 0,
          isActive: input.isActive ?? true,
          ...(await image(input.imageMediaId)),
        },
      });
      return toPublicCategory(category);
    },

    async update(id: string, input: Partial<CategoryInput>): Promise<PublicCategory> {
      await get(id);
      if (input.parentId !== undefined) await checkParent(input.parentId, id);
      const category = await db.category.update({
        where: { id },
        data: {
          name: input.name,
          nameI18n: i18nJson(input.nameI18n),
          parentId: input.parentId,
          sortOrder: input.sortOrder,
          isActive: input.isActive,
          ...(await image(input.imageMediaId)),
        },
      });
      return toPublicCategory(category);
    },

    /** Soft delete. Refused while it still has sub-categories or products, so nothing is orphaned silently. */
    async remove(id: string): Promise<void> {
      await get(id);
      const [children, products] = await Promise.all([
        db.category.count({ where: { parentId: id, deletedAt: null } }),
        db.product.count({ where: { categoryId: id, deletedAt: null } }),
      ]);
      if (children > 0 || products > 0) {
        throw new AppError('CATEGORY_NOT_EMPTY', 409, 'Move or delete its products and sub-categories first', {
          subCategories: children,
          products,
        });
      }
      await db.category.update({ where: { id }, data: { deletedAt: now() } });
    },

    /** The category and its sub-categories (for "show everything in Dairy"). */
    async withChildren(id: string): Promise<string[]> {
      const children = await db.category.findMany({ where: { parentId: id, deletedAt: null }, select: { id: true } });
      return [id, ...children.map((c) => c.id)];
    },
  };
}

export type CategoriesService = ReturnType<typeof createCategoriesService>;
